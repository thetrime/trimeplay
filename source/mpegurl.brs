Function load_mpegurl(reply as Object, socket as Object)
    ' First step is to read the entire file
    if reply.headers["connection"] <> invalid and reply.headers["connection"] = "close" then
        GetGlobalAA().connections[Stri(socket.getID())] = invalid
        socket.close()
        print "Must connect again"
        load_mpegurl_parameters(reply.hostname, reply.port, reply.path)
    else
        print "Reusing connection"
        send_mpegurl_request_on_socket(reply, socket)
    end if
End Function

Function send_mpegurl_request_on_socket(request as Object, socket as Object)
    if socket.eOK() and socket.isWritable() then
        socket.notifyWritable(false) 'shut up shut up SHUT UP!
        print "Sending mpegurl request on " ; socket.getID()
        reply = create_new_reply()
        GetGlobalAA().connections[Stri(socket.getID())] = reply
        reply.process_data = handle_mpegurl_data
        reply.hostname = request.hostname
        reply.port = request.port
        reply.path = request.path
        packet = createobject("roByteArray")
        msg = "GET " + request.path + " HTTP/1.1" + chr(13) + chr(10) + "Host: " + request.hostname + chr(13) + chr(10) + chr(13) + chr(10)
        print msg
        packet.fromAsciiString(msg)
        socket.send(packet, 0, packet.Count())
        return false
    Else
        ' They hung up on us!
        print "Hangup detected?"
        load_mpegurl_parameters(request.hostname, request.port, request.path, request.start_byte, request.end_byte)
        return true
    End If
End Function


Sub load_mpegurl_parameters(hostname as String, port as integer, path as String)
    print "Loading mpegurl parameters for " ; hostname ; " on port " ; port ; " on path " ;path
    socket = createobject("roStreamSocket")
    socket.setMessagePort(GetGlobalAA().port)
    mpegurl_addr = CreateObject("roSocketAddress")
    mpegurl_addr.setPort(port)
    mpegurl_addr.setHostName(hostname)      
    reply = create_new_reply()
    GetGlobalAA().sockets[Stri(socket.getID())] = socket
    GetGlobalAA().connections[Stri(socket.getID())] = reply
    reply.read_data = send_mpegurl_request_on_socket
    reply.path = path
    reply.hostname = hostname
    reply.port = port
    socket.setSendToAddress(mpegurl_addr)
    socket.notifyReadable(true)
    socket.notifyWritable(true)
    print "Connecting to get mpegurl data on " ; socket.getID()
    socket.connect()
End Sub

Function read_line(request as Object)
    r = ""
    While request.body.Count() > 0
        code = request.body.Shift()
        if code = 13 then
            if request.body[0] = 10 then
                request.body.shift()
            end if
            return r
        end if
        if code = 10 then
            return r
        end if
        r = r + chr(code)
    End While
    return r
End Function

Function path_prefix(request as Object)
    bytes = createobject("roByteArray")
    bytes.fromAsciiString(request.path)
    While bytes.count() > 0
        code = bytes.pop()
        if code = 47 Then
            bytes.push(47)
            return bytes.toAsciiString()
        End If
    End While
    return ""
End Function

Function handle_mpegurl_data(request as Object, socket as Object)
    header = read_line(request)
    state = 0
    print "Header: " ; header
    duration = 0
    if header <> "#EXTM3U" then
       print "unexpected header"
       stop
    end if
    while request.body.Count() > 0
        info = read_line(request)
        print "Line: " ; info
        if starts_with(info, "#EXT-X-STREAM-INF:") then
            ' Ok, this is a link to another stream. Assume this is the only one of interest
            suffix = read_line(request)
            new_path = path_prefix(request) + suffix
            print "New path: " ; new_path
            start_media({protocol: "http"
                             port: request.port
                         hostname: request.hostname
                             path: new_path})
            return true
        else if starts_with(info, "#EXTINF:")
            print "Increasing duration: " ; info
            duration = duration + val(right(info, len(info) - 8))
        end if        
    end while

    ' Ok, so presumably now we have a duration. Let's start the movie!
    GetGlobalAA().video_duration = duration
    print "Movie length detected to be " ; GetGlobalAA().video_duration ; " seconds"
    content = {}
    play_start = Int(GetGlobalAA().video_duration * GetGlobalAA().current_video_fraction)
    print "Starting from " ; play_start ; "(of type " ; type(play_start) ; ")"
    content.Stream = { url:GetGlobalAA().current_video_url
                   quality:false
                 contentid:"airplay-content"}
    content.length = int(GetGlobalAA().video_duration)
    content.playstart = play_start
    content.StreamFormat = "hls" ' Apparently. This caught me out a few times!
    GetGlobalAA().video_state = 0
    aa = GetGlobalAA()
    aa.video_screen.setContent(content)
    aa.video_screen.Pause()
    return true
End Function
