Sub start_media(url as Object)
    ' Hokay. First, we don't even know the media type. Let's open a connection so we can ask about it
    print "Loading media parameters for " ; url
    socket = createobject("roStreamSocket")
    socket.setMessagePort(m.port)
    media_addr = CreateObject("roSocketAddress")
    media_addr.setPort(url.port)
    media_addr.setHostName(url.hostname)      
    request = create_new_request()
    m.connections[Stri(socket.getID())] = request
    m.sockets[Stri(socket.getID())] = socket
    ' Slightly confusing, but 'read data' also means 'when connected'. We change it once we have written the message
    request.read_data = get_media_type 
    request.process_data = invalid
    ' Also copy in some other stuff we need in a bit
    request.path = url.path
    request.hostname = url.hostname
    request.port = url.port
    socket.setSendToAddress(media_addr)
    socket.notifyReadable(true)
    socket.notifyWritable(true)
    socket.connect()
    ' And now we wait
End Sub

Function get_media_type(request as Object, socket as Object)
    reply = create_new_reply()
    reply.process_data = process_media_type

    ' Switch out the request for the reply
    GetGlobalAA().connections[Stri(socket.getID())] = reply

    ' But don't forget to copy across the important stuff
    reply.hostname = request.hostname
    reply.port = request.port
    reply.path = request.path

    packet = createobject("roByteArray")
    ' Originally I wanted to do HEAD here, and examine the content-type. Well, guess what? 
    ' iOS just disconnects if I ask for HEAD. Worse, everything is reported to be content-type: application/octet-stream. Great.
    msg = "GET " + request.path + " HTTP/1.1" + chr(13) + chr(10) + "Host: " + request.hostname + chr(13) + chr(10) + "Range: bytes=0-8" + chr(13) + chr(10) + chr(13) + chr(10)
    print msg
    socket.notifyWritable(false)
    packet.fromAsciiString(msg)
    print socket.send(packet, 0, packet.Count())
    return false ' Do not try to process media type yet, though, since we don't have it!
End Function

Function process_media_type(reply as Object, socket as Object)
    ' First off, was this a redirect? If so, we have to start all over again anyway
    if reply.status = "302" Then
        ' Redirect
        socket.close()
        GetGlobalAA().connections[Stri(socket.getID())] = invalid
        GetGlobalAA().sockets[Stri(socket.getID())] = invalid
        new_url = parse_url(reply.headers["location"])
        print "Following redirect to " ; new_url
        start_media(new_url)
        return true ' Socket is already gone
    end if

    ' No, this is the real deal
    ' Heuristic time. First, if the header tells us, great
    if Lcase(reply.headers["content-type"]) = "something" then
        stop
    else
        ' Ok, so how about the body?
        if reply.body[4] = 102 and reply.body[5] = 116 and reply.body[6] = 121 and reply.body[7] = 112 then
            ' MP4 (probably)
            print "MP4 signature detected"
            load_mp4_file(reply, socket)
        else
            print "Unknown file type :("
            stop
        end if
    end if
    return false
End Function
