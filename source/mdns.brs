' This module takes care of the ugly business of mDNS responses and broadcasts

Sub respond_to_dns(dns as Object, udp as Object)
    For Each question in dns["questions"]
        uri = ""
        For Each part in question
            uri = uri + part + "."
        End For
        'print "Query received for " ; uri
        If uri = "_raop._tcp.local." or uri = "_airplay." or uri = "_raop." or uri = "_services._dns-sd._udp.local." or  uri = "roku._airplay._tcp.local." or uri = "roku._airplay.roku._airplay." or uri = "_airplay._tcp.local." or uri = "_raop._raop." Then 
            announce = announce_packet()
            'print "Announcing...."
            result = udp.send(announce, 0, announce.Count())
        End If
    End For
End Sub

Function parse_question(message as Object, questions as Object, history as Object, n as integer)
    parts = []
    length = message.Shift()
    n = n + 1
    While length <> 0
        part = ""
        If length = 192
           ' This is a pointer-type record, which is horrifically difficult for me to parse
           offset = message.Shift() ' FIXME: Does not take into account low-15 bytes of first byte
           n = n + 1
           For i = offset To history.count() Step 1
               If history[i] = "" 
                  Exit For
               End If
               If history[i] <> invalid
                  parts.push(history[i])
               End If
           End For
           Exit While
        Else
            For i = 1 To length
                part = part + chr(message.Shift())
            End For
        End If
        parts.push(part)
        history[n] = part
        length = message.Shift()
        n = n + 1
    End While
    history[n] = ""

    record_type = message.Shift() * 256 + message.Shift()
    class = message.Shift() * 256 + message.Shift()
    n = n + 4
    questions.push(parts)
    return n
End Function


Function parse_dns(message as Object)
   id = 256 * message.Shift() + message.Shift()
   flags = 256 * message.Shift() + message.Shift()
   qd_count = 256 * message.Shift() + message.Shift()
   an_count = 256 * message.Shift() + message.Shift()
   ns_count = 256 * message.Shift() + message.Shift()
   ar_count = 256 * message.Shift() + message.Shift()

   questions = []
   history = []
   n = 12
   For i = 1 To qd_count Step 1
       n = parse_question(message, questions, history, n)
   End For


   return {id: id
           flags: flags
           questions: questions}
End Function

Function announce_packet()
    announce = CreateObject("roByteArray")
    
    device_info = createobject("roDeviceInfo")
    addresses = device_info.GetIPAddrs()
    ip_addresses = []
    For each address in addresses
        ip = addresses[address]
        this_address = createobject("roByteArray")
        ipbytes = createobject("roByteArray")
        ipbytes.fromAsciiString(ip)
        digit = 0
        For each byte in ipbytes
            if byte = 46
               this_address.push(digit)
               digit = 0
            Else
                digit = digit * 10 + (byte - 48)
            End If
        End For
        this_address.Push(digit)
        ip_addresses.Push(this_address)
    End For

    ' Write ID 
    announce[0] = 0
    announce[1] = 0
    ' Write flags
    announce[2] = 132 '0x84
    announce[3] = 0

    ' 1 Questions
    announce[4] = 0
    announce[5] = 1
    ' 5 Answer RRs
    announce[6] = 0
    announce[7] = 8
    ' 0 Authority RRs
    announce[8] = 0
    announce[9] = 0
    ' 1 Additional RRs
    announce[10] = 0
    announce[11] = ip_addresses.count()
    
    encode_questions(announce, [["roku", "_airplay", "_tcp", "local"]])
'-----------------------------------------------------------------------------------------------------------
    data = [{qname:["roku", "_airplay", "_tcp", "local"],
              text:["deviceid=" + m.mac,
                    "features=" + m.features_hex,
                    "model=AppleTV2,1"
                    "srcvers=101.28"]},

            {qname:[m.mac_no_colon + "@roku", "_raop", "_tcp", "local"],
              text:["txtvers=1"
                    "ch=2"
                    "cn=0,1,2,3"
                    "da=true"
                    "et=0,3,5"
                    "md=0,1,2"
                    "pw=false"
                    "sv=false"
                    "sr=44100"
                    "ss=16"
                    "tp=UDP"
                    "vn=65537"
                    "vs=130.14"
                    "am=AppleTV2,1"
                    "sf=0x4"]},

            {qname:["_services", "_dns-sd", "_udp", "local"],
               ptr:["_airplay", "_tcp", "local"]},

            {qname:["_services", "_dns-sd", "_udp", "local"],
               ptr:["_raop", "_tcp", "local"]},

            {qname:["_airplay", "_tcp", "local"],
               ptr:["roku", "_airplay", "_tcp", "local"]},

            {qname:["_raop", "_tcp", "local"],
               ptr:[m.mac_no_colon+"@roku", "_raop", "_tcp", "local"]},

            {qname:["roku", "_airplay", "_tcp", "local"],
           service:{port:7000,
                hostname:["roku", "local"]}},
  
            {qname:[m.mac_no_colon + "@roku", "_raop", "_tcp", "local"],
           service:{port:7100,
                hostname:["roku", "local"]}}]


    For Each ip in ip_addresses
        data.push({qname:["roku", "local"],
                       a:ip})
    End For
    encode_answers(announce, data)
                                 
    return announce
End Function


Sub encode_questions(announce as Object, questions as Object)
    For Each question in questions
        encode_qname(announce, question)
        ' Set the type to ANY
        announce.Push(0)
        announce.Push(255)

        ' Set the class to IN, QU = false
        announce.Push(0)
        announce.Push(1)       
    End For
End Sub


Sub encode_answers(announce as Object, answers as Object)
    For Each answer in answers
        encode_qname(announce, answer["qname"])
        If answer["service"] <> invalid
           encode_service(announce, answer["service"])
        Else If answer["ptr"] <> invalid
           encode_ptr(announce, answer["ptr"])
        Else If answer["text"] <> invalid
           encode_text(announce, answer["text"])
        Else If answer["a"] <> invalid
           encode_host(announce, answer["a"])
        End If
    End For
End Sub


Sub encode_ptr(announce as Object, auth as Object)
    ' Set the type to PTR
    announce.Push(0)
    announce.Push(12)

    ' Set the class to IN
    announce.Push(0)
    announce.Push(1)        

    ' TTL is 1:15:00
    set_ttl(announce, 4500)

    ' Store the length
    length = auth.Count() + 1
    For Each chunk In auth
        length = length + len(chunk)
    End For
    announce.Push(length / 256)

    announce.Push(length MOD 256)
    
    encode_qname(announce, auth)
End Sub

Sub encode_host(announce as Object, auth as Object)
    ' Set the type to A
    announce.Push(0)
    announce.Push(1)

    ' Set the class to IN
    announce.Push(0)
    announce.Push(1)        

    ' TTL is 120s
    set_ttl(announce, 120)

    ' Store the length
    announce.Push(0)
    announce.Push(4)

    For Each chunk In auth
        announce.Push(chunk)
    End For
End Sub
    
Sub set_ttl(packet as Object, ttl as integer)
    packet.Push(0)
    packet.Push(0)
    packet.Push(ttl / 256)
    packet.Push(ttl MOD 256)
End Sub

Sub encode_service(announce as Object, auth as Object)
    ' Set the type to SRV
    announce.Push(0)
    announce.Push(33)

    ' Set the class to IN
    announce.Push(0)
    announce.Push(1)        

    ' TTL is 120s
    set_ttl(announce, 120)

    ' Store the length
    length = auth["hostname"].Count() + 1
    For Each chunk In auth["hostname"]
        length = length + len(chunk)
    End For
    length = length + 6 ' Add space for priority, weight and port
    announce.Push(length / 256)
    announce.Push(length MOD 256)
    
    ' Priority 0
    announce.push(0)
    announce.push(0)

    ' Weight 0
    announce.push(0)
    announce.push(0)

    ' Port
    announce.push(auth["port"] / 256)
    announce.push(auth["port"] MOD 256)     

    ' Hostname
    encode_qname(announce, auth["hostname"])
End Sub

Sub encode_text(announce as Object, texts as Object)
    ' Set the type to TXT
    announce.Push(0)
    announce.Push(16)

    ' Set the class to IN
    announce.Push(0)
    announce.Push(1)        

    ' TTL is 1:15:00
    set_ttl(announce, 4500)

    ' Store the length
    length = texts.Count()
    For Each chunk In texts
        length = length + len(chunk)
    End For
    announce.Push(length / 256)
    announce.Push(length MOD 256)

    For Each chunk In texts
        announce.Push(len(chunk))
        bytes = createobject("roByteArray")
        bytes.fromAsciiString(chunk)
        For Each byte In bytes
            announce.Push(byte)
        End For
    End For    
End Sub



Sub encode_qname(announce as Object, items as Object)
    For Each item In items
        bytes = createobject("roByteArray")
        bytes.fromAsciiString(item)
        announce.Push(bytes.Count())
        For Each byte In bytes
            announce.Push(byte)
        End For
    End For
    announce.Push(0) ' End of qname
End Sub
