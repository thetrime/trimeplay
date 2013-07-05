Function handle_fairplay(http as Object, connection as Object)
    reply = createobject("roByteArray")
    packet = "HTTP/1.1 404 Not Found" + chr(13) + chr(10)
    reply.fromAsciiString(packet)
    status = connection.send(reply, 0, reply.Count())
    return status    
End Function

Function handle_reverse(http as Object, connection as Object)
    reply = createobject("roByteArray")
    reply.fromAsciiString("HTTP/1.1 101 Switching Protocols" + chr(13) + chr(10) + "Date: Thu, 23 Feb 2012 17:33:41 GMT" + chr(13) + chr(10) + "Upgrade: PTTH/1.0" + chr(13) + chr(10) + "Connection: Upgrade" + chr(13) + chr(10) + chr(13) + chr(10))
    status = connection.send(reply, 0, reply.Count())
    print "Reversal on: " ; connection.getID()
    GetGlobalAA().reverse_connection = connection
    GetGlobalAA().connections[Stri(connection.getId())] = create_new_reply()
    return status
End Function

Function handle_server_info(http as Object, connection as Object)
    ' Really? You cannot escape quotes?!
    device_id = "<string>" + m.mac + "</string>"
    features = "  <integer>" + m.features_dec + "</integer>"

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

Function handle_scrub(http as Object, connection as Object)
    duration = 1200 ' FIXME: No it isnt
    print "Method: " ; http.method
    if http.method = "get" then
        return send_http_reply(connection, "text/parameters", list_concat_with_newlines(["duration: " + str(duration), "position: " + str(m.video_position)]))
    else if http.method = "post" then
        ' Scrub to given position
        new_position = val(http.search["position"]) * 1000        
        print "Scrubbing to " ; new_position
        m.video_screen.Seek(Int(new_position))
        return send_http_reply(connection, "text/parameters", "")
    end if
End Function


Function handle_play(http as Object, connection as Object)
    params = {}
    name = createobject("roByteArray")
    state = 0
    if http.headers["content-type"] = "application/x-apple-binary-plist"
        ' Blast.
        print "is bplist"
        params = parse_bplist(http.body)
    Else
        For Each byte in http.body
            If byte = 58 and state = 0 Then
                value = createobject("roByteArray")
                state = 2
            Else if byte = 10 and state = 1 Then
               ' End of record
               params[Lcase(name.toAsciiString())] = value.toAsciiString()
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
        m.video_screen.AddHeader("user-agent", "QuickTime")
        m.video_screen.SetPositionNotificationPeriod(1)
        m.video_screen.SetMessagePort(m.port)
        If m.state = "photo" then
            m.photo_screen.close()
        End if
       m.video_screen.show()
    End If
    m.state = "video"

    ' We need to get the length of the video. This is incredibly difficult, despite the fact that the Roku KNOWS it
    ' There is apparently a request to provide this in the future. But tomorrow is always a day away...
    print "Url: " ; params["content-location"]
    print params
    m.current_video_url = params["content-location"]
    if type(params["start-position"]) = "String" then
        m.current_video_fraction = val(params["start-position"])
    else
        m.current_video_fraction = params["start-position"]
    end if
    url = parse_url(params["content-location"])
    'load_video_parameters(url.hostname, url.port, url.path, "0", "1024")
    start_media(url)
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
    If m.video_state = 0 or m.video_state = 2 Then    
        f_rate = "0"
    Else
        f_rate = "1"
    End If
    duration = "1451.000000" 'FIXME: No it isnt
    position = str(m.video_position) ' FIXME: trim spaces?
    body= list_concat_with_newlines(["<?xml version=" + chr(34) + "1.0" + chr(34) + " encoding=" + chr(34) + "UTF-8" + chr(34) + "?>",
                                                                                        "<!DOCTYPE plist PUBLIC " + chr(34) + "-//Apple//DTD PLIST 1.0//EN" + chr(34) + " " + chr(34) + "http://www.apple.com/DTDs/PropertyList-1.0.dtd" + chr(34) + ">",
                                                                                        "<plist version=" + chr(34) + "1.0" + chr(34) + ">",
                                                                                        " <dict>",
                                                                                        "   <key>duration</key>",
                                                                                        "   <real>"+duration+"</real>",
                                                                                        "   <key>loadedTimeRanges</key>",
                                                                                        "   <array>",
                                                                                        "     <dict>",
                                                                                        "       <key>duration</key>",
                                                                                        "       <real>"+duration+"</real>",
                                                                                        "       <key>start</key>",
                                                                                        "       <real>0.0</real>",
                                                                                        "     </dict>",
                                                                                        "   </array>",
                                                                                        "   <key>playbackBufferEmpty</key>",
                                                                                        "   <true/>",
                                                                                        "   <key>playbackBufferFull</key>",
                                                                                        "   <false/>",
                                                                                        "   <key>playbackLikelyToKeepUp</key>",
                                                                                        "   <true/>",
                                                                                        "   <key>position</key>",
                                                                                        "   <real>"+position+".0</real>"
                                                                                        "   <key>rate</key>",
                                                                                        "   <real>" + f_rate + "</real>"
                                                                                        "   <key>readyToPlay</key>"
                                                                                        "   <true/>",
                                                                                        "   <key>seekableTimeRanges</key>",
                                                                                        "   <array>",
                                                                                        "     <dict>",
                                                                                        "       <key>duration</key>"
                                                                                        "       <real>" + duration + "</real>",
                                                                                        "       <key>start</key>",
                                                                                        "       <real>0.0</real>",
                                                                                        "     </dict>",
                                                                                        "   </array>",
                                                                                        " </dict>",
                                                                                        "</plist>"])

    return send_http_reply(connection, "text/x-apple-plist+xml", body)

End Function


Function handle_rate(http as Object, connection as Object)
    print http.search["value"]
    if val(http.search["value"]) = 0 Then
       print "Pausing"
       m.video_screen.Pause()
       m.video_state = 2
    Else if val(http.search["value"]) = 1 Then
       print "Resuming"
       m.video_screen.Resume()
       m.video_state = 1
    Else
       print "unexpected rate:" ; http.search["value"]
    End If
    return send_http_reply(connection, "text/x-apple-plist+xml", "")
End Function

Function handle_get_property(http as Object, connection as Object)
    print http.search
    ' FIXME: not implemented
    return send_http_reply(connection, "text/x-apple-plist+xml", "")
End Function



Function list_concat_with_newlines(chunks as Object)
    output = ""
    For Each chunk in chunks
        output = output + chunk + chr(10)
    End For
    return output
End Function

Function pad_integer(source as Integer)
    if source < 10 Then
        return "0" + right(str(source), 1)
    Else
        return right(str(source), 2)
    End If
End Function

Function send_http_reply(connection as Object, content_type as String, data as String)
    reply = createobject("roByteArray")
    date = createobject("roDateTime")
    months = ["placeholder"
              "Jan"
              "Feb"
              "Mar"
              "Apr"
              "May"
              "Jun"
              "Jul"
              "Aug"
              "Sep"
              "Oct"
              "Nov"
              "Dec"]
    month_name = months[date.getMonth()]
    ' WHY does str(6) return " 6" ?!
    rfc822 = Left(date.GetWeekday(), 3) + ", " + pad_integer(date.GetDayOfMonth()) + " " + month_name + " " + right(str(date.getYear()), 4) + " " + pad_integer(date.getHours()) + ":" + pad_integer(date.getMinutes()) + ":" + pad_integer(date.getSeconds()) + " GMT"
    packet = "HTTP/1.1 200 OK" + chr(13) + chr(10)
    packet = packet + "Date: " + rfc822 + chr(13) + chr(10)    
    'packet = packet + "Date: Thu, 23 Feb 2012 17:33:41 GMT" + chr(13) + chr(10)
    packet = packet + "Content-Type: " + content_type + chr(13) + chr(10)
    packet = packet + "Content-Length: " + str(len(data)) + chr(13) + chr(10) + chr(13) + chr(10)
    packet = packet + data
    reply.fromAsciiString(packet)
    status = connection.send(reply, 0, reply.Count())
    return status
End Function


Function dispatch_http(http as Object, connection as Object)
    if http.path <> "/playback-info" ' Cut down on noise
         print "Handling " ; http.path
    end if
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
    Else If http.path = "/scrub" Then
        status = handle_scrub(http, connection)
    Else If http.path = "/fp-setup" Then
        status = handle_fairplay(http, connection)
    Else If http.path = "/getProperty" Then
        status = handle_get_property(http, connection)
    Else If http.path = "/proxy" Then
        status = handle_proxy(http, connection)
    Else
        print "Unexpected URI: "; http.path ; " on " ; connection.getID()
    End If
    'print "Status: " ; status
    return false ' Keep-alive
End Function
