class Game
  constructor: (@user) ->
    @lineRef = new Firebase('https://songzdemo.firebaseIO.com/waitlist/')
    console.log( "I am "+@user.id )
    $("#loginContainer").hide()
    $.get "http://apigenerator.herokuapp.com/getSession?contact=#{@user.id}", (r) =>
      @apiKey = r.apiKey
      @publisher = TB.initPublisher(@apiKey, 'myPublisherDiv')
      @sessionId = r.session_id
      @token = r.token
    @total = 0
    return
  startVideoChat: (sid) =>
    @session = TB.initSession( @sessionId )
    @session.addEventListener('sessionConnected', @sessionConnectedHandler)
    @session.addEventListener('streamCreated', @streamCreatedHandler)
    @session.addEventListener("streamDestroyed", @streamDestroyedHandler)
    @session.addEventListener("sessionDisconnected", @sessionDisconnectedHandler)
    @session.connect(@apiKey, @token)
  startWaiting: =>
    myRef = new Firebase('https://songzdemo.firebaseIO.com/waitlist/'+@user.id)
    myRef.set(sessionId: @sessionId )
    myRef.onDisconnect().remove()
    @startVideoChat( @sessionId )
    console.log( "no one available. Add to waitinglist" )
  findNew: =>
    if( $("#startStopButton").text() == "Start" )
      return
    if( @session && @session.disconnect )
      console.log "disconnect in findNew"
      @session.disconnect()
      return
    @lineRef.once 'value', (dataSnapshot) =>
      if( dataSnapshot.hasChildren() )
        for k of dataSnapshot.val()
          if( k.toString() != @user.id.toString() )
            targetRef = @lineRef.child( k )
            targetRef.once "value", ( targetSnapshot ) =>
              val = targetSnapshot.val()
              if val
                console.log "connecting to: #{k}"
                @startVideoChat( targetSnapshot.val().sessionId )
                targetRef.parent().remove()
                return
      else
        @startWaiting()
  tooManyUsers: (streams) =>
    nStreams = 0
    for e in streams
      # Make sure we don't subscribe to ourself
      if (e.connection.connectionId != @session.connection.connectionId)
        nStreams += 1
        if nStreams >= 2
          return true
    return false
  sessionConnectedHandler: (event) =>
    console.log "sessionConnected"
    if @tooManyUsers(event.streams)
      console.log "tooManyUsers"
      @session.disconnect()
      return
    @subscribeToStreams(event.streams)
    window.setTimeout( ()=>
      if @total >= 2
        console.log "timeout, too many users"
        @session.disconnect()
      @session.publish(@publisher)
    , Math.floor( Math.random()*2000 ))
  streamCreatedHandler: (event) =>
    @subscribeToStreams(event.streams)
  subscribeToStreams: (streams) =>
    for e in streams
      # Make sure we don't subscribe to ourself
      if (e.connection.connectionId == @session.connection.connectionId)
        return
      div = document.createElement('div')
      div.setAttribute('id', 'stream' + e.streamId)
      $("#subscriberContainer").append( div )
      @session.subscribe(e, div.id)
      @total += 1
  sessionDisconnectedHandler: (event) =>
    console.log "sessionDisconnected"
    @total = 0
    $("#subscriberContainer").html("")
    @session.removeEventListener('sessionConnected', @sessionConnectedHandler)
    @session.removeEventListener('streamCreated', @streamCreatedHandler)
    @session.removeEventListener("streamDestroyed", @streamDestroyedHandler)
    @session.removeEventListener("sessionDisconnected", @sessionDisconnectedHandler)
    event.preventDefault()
    @session = ""
    window.setTimeout( ()=>
      @findNew()
    , Math.floor( Math.random()*2000 ))
  streamDestroyedHandler: (event) =>
    @findNew()

game = ""

# authentication
chatRef = new Firebase('https://songzdemo.firebaseIO.com')
authClient = new FirebaseAuthClient chatRef, (error, user) ->
  if (error)
    console.log(error)
  else
    if (user)
      game = new Game({id:user.id})
$("#fbLoginButton").click ->
  authClient.login( 'Facebook' )

# button startGame
$("#startStopButton").click ()->
  if( $(this).text() == "Start" )
    $(this).text('Stop')
    game.findNew()
  else
    $(this).text('Start')

$("#nextButton").click ()->
  game.findNew()
