Function load_mp4_file(reply as Object, socket as Object)
    if reply.headers["connection"] <> invalid and reply.headers["connection"] = "close" then
        GetGlobalAA().connections[Stri(connection.getID())] = invalid
        connection.close()
        print "Must connect again"
        load_mp4_parameters(reply.hostname, reply.port, reply.path, "0", "1024")
    else
        print "Reusing connection"
        send_mp4_request_on_socket(socket, reply.path, reply.hostname, reply.port, "0", "1024")
    end if
End Function

Function handle_mp4_data(request as Object, connection as Object)
    print "Got some delicious MP4 data!"
    ' Read the length of the atom as a string, because otherwise brightscript will screw it up :(
    atom_length = add_byte("0", request.body.shift())
    atom_length = add_byte(atom_length, request.body.shift())
    atom_length = add_byte(atom_length, request.body.shift())
    atom_length = add_byte(atom_length, request.body.shift())

    atom_name = chr(request.body.shift())
    atom_name = atom_name + chr(request.body.shift())
    atom_name = atom_name + chr(request.body.shift())
    atom_name = atom_name + chr(request.body.shift())
    
    print "Atom is " ; atom_name ; " and is of length " ; atom_length
    if atom_length = "1" then
        ' 64-bit atom length follows       
        atom_length = add_byte("0", request.body.shift())
        atom_length = add_byte(atom_length, request.body.shift())
        atom_length = add_byte(atom_length, request.body.shift())
        atom_length = add_byte(atom_length, request.body.shift())
        atom_length = add_byte(atom_length, request.body.shift())
        atom_length = add_byte(atom_length, request.body.shift())
        atom_length = add_byte(atom_length, request.body.shift())
        atom_length = add_byte(atom_length, request.body.shift())
        'print "Atom is ACTUALLY of length " ; atom_length
    end if    

    if atom_name = "moov" then
        ' Awesome. Now we need to find the mvhd atom by descending INTO the moov atom
        if atom_length = "1" then
            ' Skip 64-bit extension size too
            new_start = add_strings(request.start_range, "16")
        else
            new_start = add_strings(request.start_range, "8")
        end if
        new_end = add_strings(new_start, "1024")
        return continue_loading_mp4(request, connection, new_start, new_end)
    else if atom_name = "mvhd" then
        ' Sweet. Now we can get the data we crave!
        timescale = (((((request.body[12] * 256) + request.body[13]) * 256) + request.body[14]) * 256) + request.body[15]
        duration = (((((request.body[16] * 256) + request.body[17]) * 256) + request.body[17]) * 256) + request.body[19]
        GetGlobalAA().video_duration = duration / timescale
        print "Movie length detected to be " ; GetGlobalAA().video_duration ; " seconds"
        ' Got it. Mark everything as invalid and hang up!
        GetGlobalAA().connections[Stri(connection.getID())] = invalid
        connection.close()
        ' Now we can finally start playing the video
        content = {}
        play_start = Int(GetGlobalAA().video_duration * GetGlobalAA().current_video_fraction)
        print "Starting from " ; play_start ; "(of type " ; type(play_start) ; ")"
        content.Stream = { url:GetGlobalAA().current_video_url
                       quality:false
                     contentid:"airplay-content"}
        content.length = int(GetGlobalAA().video_duration)
        content.playstart = play_start
        content.StreamFormat = "mp4"
        GetGlobalAA().video_state = 0
        aa = GetGlobalAA()
        aa.video_screen.setContent(content)
        aa.video_screen.Pause()
        return true ' Done. Socket is already closed (FIXME: Should we wait until after returning?)
    else
        ' Oh well. Skip this atom        
        new_start = add_strings(request.start_range, atom_length)
        new_end = add_strings(new_start, "1024")
        return continue_loading_mp4(request, connection, new_start, new_end)
    End if       
End Function

Function continue_loading_mp4(reply as Object, socket as Object, new_start as String, new_end as String)
    if reply.headers["connection"] <> invalid and reply.headers["connection"] = "close" then
        GetGlobalAA().connections[Stri(socket.getID())] = invalid
        connection.close()
        load_mp4_parameters(reply.hostname, reply.port, reply.path, new_start, new_end)
        return true ' Socket is now invalid (FIXME: Should we wait until after returning?)
    else
        send_mp4_request_on_socket(socket, reply.path, reply.hostname, reply.port, new_start, new_end)
        return false ' Do not close the socket
    end if
End Function



Sub load_mp4_parameters(hostname as String, port as integer, path as String, start_byte as String, end_byte as String)
    print "Loading mp4 parameters for " ; hostname ; " on port " ; port ; " on path " ;path
    socket = createobject("roStreamSocket")
    socket.setMessagePort(GetGlobalAA().port)
    mp4_addr = CreateObject("roSocketAddress")
    mp4_addr.setPort(port)
    mp4_addr.setHostName(hostname)      
    reply = create_new_reply()
    GetGlobalAA().sockets[Stri(socket.getID())] = socket
    reply.read_data = send_mp4_request_on_socket
    request.process_data = handle_mp4_data    
    request.path = path
    request.hostname = hostname
    request.port = port
    request.start_byte = start_byte
    request.end_byte = end_byte
    socket.setSendToAddress(mp4_addr)
    socket.notifyReadable(true)
    socket.notifyWritable(true)
    print "Connecting to get mp4 data on " ; socket.getID()
    socket.connect()
End Sub



' We have to keep the ranges as strings, since brightscript will coerce them to floats, and print them out in scientific notation
' which iOS does not care for. Worse, because we lose precision, we cannot reliably get it back
' add_strings() below adds two strings
Sub send_mp4_request_on_socket(socket as Object, path as string, hostname as string, port as Integer, start_range as string, end_range as string)    
    if socket.eOK() and socket.isWritable() then
        socket.notifyWritable(false) 'shut up shut up SHUT UP!
        print "Sending mp4 request on " ; socket.getID()
        reply = create_new_reply()
        GetGlobalAA().connections[Stri(socket.getID())] = reply
        reply.start_range = start_range
        reply.process_data = handle_mp4_data
        print "zap: " ; reply.process_data = handle_mp4_data
        reply.hostname = hostname
        reply.port = port
        reply.path = path
        reply.start_byte = start_range  
        reply.end_byte = end_range
        packet = createobject("roByteArray")
        request = "GET " + path + " HTTP/1.1" + chr(13) + chr(10) + "Host: " + hostname + chr(13) + chr(10) + "Range: bytes=" + start_range +"-" + end_range + chr(13) + chr(10) + chr(13) + chr(10)
        print request
        packet.fromAsciiString(request)
        socket.send(packet, 0, packet.Count())
    Else
        ' They hung up on us!
        print "Hangup detected?"
        stop
        load_mp4_parameters(hostname, port, path, start_range, end_range)
    End If
End Sub
    
