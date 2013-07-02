Function handle_mp4_data(connection as Object, request as Object)
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
        load_video_parameters(request.hostname, request.port, request.path, new_start, new_end)
        connection.close()
        'send_mp4_request(connection, request.path, new_start, new_end, request.hostname, request.port)
    else if atom_name = "mvhd" then
        ' Sweet. Now we can get the data we crave!
        timescale = (((((request.body[12] * 256) + request.body[13]) * 256) + request.body[14]) * 256) + request.body[15]
        duration = (((((request.body[16] * 256) + request.body[17]) * 256) + request.body[17]) * 256) + request.body[19]
        m.video_duration = duration / timescale
        print "Movie length detected to be " ; m.video_duration ; " seconds"
        ' Got it. Mark everything as invalid and hang up!
        m.mp4_connections[Stri(connection.getID())] = invalid
        m.connections[Stri(connection.getID())] = invalid
        connection.close()
        ' Now we can finally start playing the video
        content = {}
        print type(m.current_video_fraction)
        print type(m.video_duration)
        play_start = Int(m.video_duration * m.current_video_fraction)
        print "Starting from " ; play_start ; "(of type " ; type(play_start) ; ")"
        content.Stream = { url:m.current_video_url
                       quality:false
                     contentid:"airplay-content"}
        content.length = int(m.video_duration)
        content.playstart = play_start
        content.StreamFormat = "mp4"
        m.video_state = 0
        m.video_screen.setContent(content)
        m.video_screen.Pause()
    else
        ' Oh well. Skip this atom        
        new_start = add_strings(request.start_range, atom_length)
        new_end = add_strings(new_start, "1024")
        load_video_parameters(request.hostname, request.port, request.path, new_start, new_end)
        connection.close()
        'send_mp4_request(connection, request.path, new_start, new_end, request.hostname, request.port)
    End if       
End Function
