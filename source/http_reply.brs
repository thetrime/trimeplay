Function handle_reverse(http as Object, connection as Object)
    reply = createobject("roByteArray")
    reply.fromAsciiString("HTTP/1.1 101 Switching Protocols" + chr(13) + chr(10) + "Date: Thu, 23 Feb 2012 17:33:41 GMT" + chr(13) + chr(10) + "Upgrade: PTTH/1.0" + chr(13) + chr(10) + "Connection: Upgrade" + chr(13) + chr(10) + chr(13) + chr(10))
    status = connection.send(reply, 0, reply.Count())
    print "Reversal: " ; connection.getID()
    m.reversals[Stri(connection.getID())] = connection
    return status
End Function

Function handle_server_info(http as Object, connection as Object)
    ' Really? You cannot escape quotes?!
    device_id = "<string>" + m.mac + "</string>"
    features = "  <integer>" + m.features + "</integer>"

    return send_http_reply(connection, "text/x-apple-plist+xml", list_concat_with_newlines(["<?xml version=" + chr(34) + "1.0" + chr(34) + " encoding=" + chr(34) + "UTF-8" + chr(34) + "?>",
                                                                                            "<!DOCTYPE plist PUBLIC " + chr(34) + "-//Apple//DTD PLIST 1.0//EN" + chr(34) + " " + chr(34) + "http://www.apple.com/DTDs/PropertyList-1.0.dtd" + chr(34) + ">",
                                                                                            "<plist version=" + chr(34) + "1.0" + chr(34) + ">",
                                                                                            " <dict>",
                                                                                            "  <key>deviceid</key>",
                                                                                            device_id
                                                                                            "  <key>features</key>",
                                                                                            "  <key>model</key>",
                                                                                            "  <string>AppleTV2,1</string>",
                                                                                            "  <key>protovers</key>",
                                                                                            "  <string>1.0</string>",
                                                                                            "  <key>srcvers</key>",
                                                                                            "  <string>120.2</string>",
                                                                                            " </dict>",
                                                                                            "</plist>"]))
End Function


Function handle_slideshow_features(http as Object, connection as Object)
    ' Really? You cannot escape quotes?!
    return send_http_reply(connection, "text/x-apple-plist+xml", list_concat_with_newlines(["<?xml version=" + chr(34) + "1.0" + chr(34) + " encoding=" + chr(34) + "UTF-8" + chr(34) + "?>",
                                                                                            "<!DOCTYPE plist PUBLIC " + chr(34) + "-//Apple//DTD PLIST 1.0//EN" + chr(34) + " " + chr(34) + "http://www.apple.com/DTDs/PropertyList-1.0.dtd" + chr(34) + ">",
                                                                                            "<plist version=" + chr(34) + "1.0" + chr(34) + ">",
                                                                                            " <dict>",
                                                                                            "  <key>themes</key>",
                                                                                            "  <array>",
                                                                                            "    <dict>",
                                                                                            "      <key>key</key>",
                                                                                            "      <string>Reflections</string>",
                                                                                            "    </dict>",
                                                                                            "  </array>",
                                                                                            " </dict>",
                                                                                            "</plist>"]))
End Function

Function handle_stream(http as Object, connection as Object)
    ' Really? You cannot escape quotes?!
    return send_http_reply(connection, "text/x-apple-plist+xml", list_concat_with_newlines(["<?xml version=" + chr(34) + "1.0" + chr(34) + " encoding=" + chr(34) + "UTF-8" + chr(34) + "?>",
                                                                                            "<!DOCTYPE plist PUBLIC " + chr(34) + "-//Apple//DTD PLIST 1.0//EN" + chr(34) + " " + chr(34) + "http://www.apple.com/DTDs/PropertyList-1.0.dtd" + chr(34) + ">",
                                                                                            "<plist version=" + chr(34) + "1.0" + chr(34) + ">",
                                                                                            " <dict>",
                                                                                            "   <key>height</key>",
                                                                                            "   <integer>720</integer>",
                                                                                            "   <key>overscanned</key>",
                                                                                            "   <true/>",
                                                                                            "   <key>refreshRate</key>",
                                                                                            "   <real>0.016666666666666666</real>",
                                                                                            "   <key>version</key>",
                                                                                            "   <string>130.14</string>",
                                                                                            "   <key>width</key>",
                                                                                            "   <integer>1280</integer>",
                                                                                            " </dict>",
                                                                                            "</plist>"]))
End Function


Function handle_photo(http as Object, connection as Object)
    print "About to save data to file..." ; str(http.body.Count())
    filename = "tmp:/" + http.headers["X-Apple-AssetKey"] + ".jpg"
    print http.body.WriteFile(filename)
    bitmap = CreateObject("roBitmap", filename)
    print "About to draw image: " ; bitmap
    If m.state <> "photo" Then
        m.photo_screen = createobject("roImageCanvas")
        m.photo_screen.SetMessagePort(m.port)
        m.photo_screen.SetLayer(0, {Color:"#FF000000", CompositionMode:"Source"}) 
        if m.state = "video" Then
            m.video_screen.Close()
        End If
        m.photo_screen.show()
    End If
    m.state = "photo"
    screen_width = m.display_size.w
    screen_height = m.display_size.h
    x_offset = Int((screen_width - bitmap.GetWidth())/2)
    y_offset = Int((screen_height - bitmap.GetHeight())/2)
    m.photo_screen.SetLayer(1, [{url:filename,
                    TargetRect:{x:x_offset, y:y_offset, w:bitmap.GetWidth(), h:bitmap.getHeight()}}])
    return send_http_reply(connection, "text/x-apple-plist+xml", "")
End Function

Function handle_stop(http as Object, connection as Object)
    If m.state = "video" Then
       m.video_screen.Close()
    Else If m.state = "photo" Then
       m.photo_screen.Close()
    End If
    m.state = "none"
    return send_http_reply(connection, "text/x-apple-plist+xml", "")
End Function

Function handle_play(http as Object, connection as Object)
    params = {}
    name = createobject("roByteArray")
    state = 0
    if http.headers["content-type"] = "application/x-apple-binary-plist"
        ' Blast.
        params = parse_bplist(http.body)
    Else
        For Each byte in http.body
            print byte
            If byte = 58 and state = 0 Then
                value = createobject("roByteArray")
                state = 2
            Else if byte = 10 and state = 1 Then
               ' End of record
               params[Lcase(name.toAsciiString())] = value.toAsciiString()
               print "Got:"; Lcase(name.toAsciiString()) ; "=" ; value.toAsciiString()
               name = createobject("roByteArray")
               state = 0
            Else if state = 2 and byte <> 32 Then
               state = 1
               value.push(byte)
            Else If state = 0 Then
               name.push(byte)
            Else If state = 1 Then
               value.push(byte)
            End If
        End For
    End If
    if m.state <> "video" Then
        m.video_screen = createobject("roVideoScreen")
        m.video_screen.SetPositionNotificationPeriod(1)
        m.video_screen.SetMessagePort(m.port)
        If m.state = "photo" then
            m.photo_screen.close()
        End if
       m.video_screen.show()
    End If
    m.state = "video"

    ' We need to get the length of the video
    'duration = mp4_duration(params["content-location"])
    duration = 1200
    playstart = Int(duration * params["start-position"])
    print "Starting at " ; playstart
    If params["content-location"] <> invalid Then
       print "start-position: " ; params["start-position"]
       content = {}

       content.Stream = { url:params["content-location"]
                             quality:false
                           contentid:"airplay-content"
                        streamformat:"mp4"
                              length:1200
                           PlayStart:50
                        PlayDuration:30}
       content.StreamFormat = "mp4"
       m.video_screen.setContent(content)
       m.video_paused = false       
    End If
    return send_http_reply(connection, "text/x-apple-plist+xml", "")
End Function



Function handle_set_property(http as Object, connection as Object)
    params = {}
    If http.headers["content-type"] = "application/x-apple-binary-plist"
        ' Expected
        params = parse_bplist(http.body)
        For Each value in params
            print value ; " = " ; params[value]
        End For
    else
        stop
    End If
    return send_http_reply(connection, "text/x-apple-plist+xml", list_concat_with_newlines(["<?xml version=" + chr(34) + "1.0" + chr(34) + " encoding=" + chr(34) + "UTF-8" + chr(34) + "?>",
                                                                                            "<!DOCTYPE plist PUBLIC " + chr(34) + "-//Apple//DTD PLIST 1.0//EN" + chr(34) + " " + chr(34) + "http://www.apple.com/DTDs/PropertyList-1.0.dtd" + chr(34) + ">",
                                                                                            "<plist version=" + chr(34) + "1.0" + chr(34) + ">",
                                                                                            " <dict>",
                                                                                            "   <key>errorCode</key>",
                                                                                            "   <integer>0</integer>",
                                                                                            " </dict>",
                                                                                            "</plist>"]))
End Function


Function handle_playback_info(http as Object, connection as Object)
    If m.video_paused Then    
        rate = "    <key>rate</key> <real>0</real>"
    Else
        rate = "    <key>rate</key> <real>1</real>"
    End If
    position = "    <key>position</key><real>" + str(m.video_position) + "</real>"

    return send_http_reply(connection, "text/x-apple-plist+xml", list_concat_with_newlines(["<?xml version=" + chr(34) + "1.0" + chr(34) + " encoding=" + chr(34) + "UTF-8" + chr(34) + "?>",
                                                                                        "<!DOCTYPE plist PUBLIC " + chr(34) + "-//Apple//DTD PLIST 1.0//EN" + chr(34) + " " + chr(34) + "http://www.apple.com/DTDs/PropertyList-1.0.dtd" + chr(34) + ">",
                                                                                        "<plist version=" + chr(34) + "1.0" + chr(34) + ">",
                                                                                        " <dict>",
                                                                                        "   <key>duration</key> <real>1801</real>",
                                                                                        "   <key>loadedTimeRanges</key>",
                                                                                        "   <array>",
                                                                                        "     <dict>",
                                                                                        "       <key>duration</key> <real>51.541130402</real>",
                                                                                        "       <key>start</key> <real>18.118717650000001</real>",
                                                                                        "     </dict>",
                                                                                        "   </array>",
                                                                                        "   <key>playbackBufferEmpty</key> <true/>",
                                                                                        "   <key>playbackBufferFull</key> <false/>",
                                                                                        "   <key>playbackLikelyToKeepUp</key> <true/>",
                                                                                        position,
                                                                                        rate,
                                                                                        "   <key>readyToPlay</key> <true/>",
                                                                                        "   <key>seekableTimeRanges</key>",
                                                                                        "   <array>",
                                                                                        "     <dict>",
                                                                                        "       <key>duration</key>"
                                                                                        "       <real>1801</real>",
                                                                                        "       <key>start</key>",
                                                                                        "       <real>0.0</real>",
                                                                                        "     </dict>",
                                                                                        "   </array>",
                                                                                        " </dict>",
                                                                                        "</plist>"]))

End Function


Function handle_rate(http as Object, connection as Object)
    print http.search["value"]
    if val(http.search["value"]) = 0 Then
       print "Pausing"
       m.video_screen.Pause()
    Else if val(http.search["value"]) = 1 Then
       print "Resuming"
       m.video_screen.Resume()
    Else
       print "unexpected rate:" ; http.search["value"]
    End If
    return send_http_reply(connection, "text/x-apple-plist+xml", "")
End Function

Function list_concat_with_newlines(chunks as Object)
    output = ""
    For Each chunk in chunks
        output = output + chunk + chr(13) + chr(10)
    End For
    return output
End Function

Function send_http_reply(connection as Object, content_type as String, data as String)
    reply = createobject("roByteArray")
    packet = "HTTP/1.1 200 OK" + chr(13) + chr(10)
    packet = packet + "Date: Thu, 23 Feb 2012 17:33:41 GMT" + chr(13) + chr(10)
    packet = packet + "Content-Type: " + content_type + chr(13) + chr(10)
    packet = packet + "Content-Length: " + str(len(data)) + chr(13) + chr(10) + chr(13) + chr(10)
    packet = packet + data
    reply.fromAsciiString(packet)
    'print data
    status = connection.send(reply, 0, reply.Count())
    return status

End Function

Function dispatch_http(http as Object, connection as Object)
    print "Handling " ; http.path
    If http.path = "/reverse" Then
        status = handle_reverse(http, connection)
    Else If http.path = "/server-info" Then
        status = handle_server_info(http, connection)
    Else If http.path = "/slideshow-features" Then
        status = handle_slideshow_features(http, connection)
    Else If http.path = "/photo" Then
        status = handle_photo(http, connection)
    Else If http.path = "/stop" Then
        status = handle_stop(http, connection)
    Else If http.path = "/play" Then
        status = handle_play(http, connection)
    Else If http.path = "/rate" Then
        status = handle_rate(http, connection)
    Else If http.path = "/stream.xml" Then
        status = handle_stream(http, connection)
    Else If http.path = "/setProperty" Then
        status = handle_set_property(http, connection)
    Else If http.path = "/playback-info" Then
        status = handle_playback_info(http, connection)
    Else
        print "Unexpected URI: "; http.path
    End If
    print "Status: " ; status
End Function