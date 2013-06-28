' Special thanks to http://code.google.com/p/plist !

Function parse_bplist(raw as Object)
    magic = createobject("roByteArray")
    trailer = createobject("roByteArray")
    ' FIXME: Why is there a spurious 0 at the end?
    raw.pop()
    For i = 1 to 6 Step 1
        magic.push(raw.Shift())
    End For
    If magic.toAsciiString() <> "bplist" Then
       print magic.toAsciiString()
       stop
    End If
    major = raw.Shift() - 48
    minor = raw.Shift() - 48
    For i = 1 to 32 Step 1
        trailer.Unshift(raw.Pop())        
    End For
    print "offsetSize: " ; trailer[6]
    offsetSize = parse_unsigned_int([trailer[6]])
    object_ref_size = parse_unsigned_int([trailer[7]])
    numObjects = parse_unsigned_int([trailer[8], trailer[9], trailer[10], trailer[11], trailer[12], trailer[13], trailer[14], trailer[15]])
    topObject = parse_unsigned_int([trailer[16], trailer[17], trailer[18], trailer[19], trailer[20], trailer[21], trailer[22], trailer[23]])
    offsetTableOffset = parse_unsigned_int([trailer[24], trailer[25], trailer[26], trailer[27], trailer[28], trailer[29], trailer[30], trailer[31]])
    offset_table = []
    For i = 0 to numObjects-1 Step 1
        bytes = createobject("roByteArray")
        For j = 0 to offsetSize-1
            bytes.Push(raw[offsetTableOffset + i * offsetSize + j-8]) ' Account for already-shifted() data
        End For
        offset_table[i] = parse_unsigned_int(bytes)
        print "Offset[";i;"] = "; offset_table[i]
    End For
    return parse_object(topObject, offset_table, raw, object_ref_size)
End Function


Function parse_object(target as integer, offset_table as Object, raw as Object, object_ref_size as integer)
    print "target: " ; target
    offset = offset_table[target]
    print "offset: " ; offset
    data = raw[offset-8]
    print "data: " ; data
    object_type = (data and 240) / 16
    object_info = (data and 15)
    print object_type ; " / " object_info
    If object_type = 0 Then
       If object_info = 0 Then
          return invalid
       Else if object_info = 8 Then
          return false
       Else if object_info = 9 Then
          return true
       Else if object_info = 12 Then
          ' URL
          stop
       Else if object_info = 13 Then
          ' URL
          stop
       Else if object_info = 14 Then
          ' UUID
          stop
       Else if object_info = 15 Then
          ' filler
          return invalid
       End If
    'Else If object_type = 1 Then
    Else If object_type = 2 Then
        ' Real
        length = 2 ^ object_info
        return val(sub_array(raw, offset + 1 - 8, offset + 1 + length - 8).toAsciiString())
    'Else If object_type = 3 Then
    'Else If object_type = 4 Then
    Else If object_type = 5 Then
        ' String
        string_info = read_length_and_offset(object_info, offset, raw)
        return sub_array(raw, offset + string_info.offset-8, offset + string_info.offset-8 + string_info.length).toAsciiString()
    'Else If object_type = 6 Then
    'Else If object_type = 8 Then
    'Else If object_type = 10 Then
    'Else If object_type = 11 Then
    'Else If object_type = 12 Then
    Else If object_type = 13 Then
        ' Dictionary
        dictionary = {}
        dictionary_info = read_length_and_offset(object_info, offset, raw)
        for i = 0 to dictionary_info.length - 1
            print "Key is from " ; (offset + dictionary_info.offset + i * object_ref_size -8) ; " to " ; (offset + dictionary_info.offset + (i + 1) * object_ref_size - 8)
            key_ref = parse_unsigned_int(sub_array(raw, offset + dictionary_info.offset + i * object_ref_size -8, offset + dictionary_info.offset + (i + 1) * object_ref_size - 8))
            value_ref = parse_unsigned_int(sub_array(raw, offset + dictionary_info.offset + (dictionary_info.length * object_ref_size) + i * object_ref_size - 8, offset + dictionary_info.offset + (dictionary_info.length * object_ref_size) + (i + 1) * object_ref_size - 8))
             key = parse_object(key_ref, offset_table, raw, object_ref_size)
             print "key: " ; key
             value = parse_object(value_ref, offset_table, raw, object_ref_size)
             print "Value: " ; value
             dictionary[key] = value
        End For
        return dictionary
    Else
        stop
    End If
End Function

Function sub_array(data as Object, start as integer, finish as integer)
    output = createobject("roByteArray")
    for i = start to finish-1
        output.push(data[i])
    End for
    return output
End Function

Function parse_unsigned_int(bytes as Object)
    l = 0
    For Each byte in bytes
        l = l * 256
        l = l or (byte and 255)
    End For
    return (l and 4294967295)
End Function

Function read_length_and_offset(object_info as integer, offset as integer, raw as Object)
    length = object_info
    stroffset = 1
    if object_info = 15 Then
       int_type = raw[offset + 1 - 8]
       print "int_type: " ; int_type
       int_type = (int_type and 240) / 16
       int_info = (raw[offset + 1 - 8] and 15)
       print "int_info:" ; int_info
       int_length = 2 ^ int_info
       stroffset = 2 + int_length
       print "stroff: " ; stroffset
       bytes = createobject("roByteArray")
       For i = offset + 2 to offset + 2 + int_length-1 step 1
           print "Accepting byte " ; (i-8) ; " = " raw[i-8]
           bytes.push(raw[i-8])
       End For       
       length = parse_unsigned_int(bytes)
    End If
    print "length: " ; length ; " stroff: " ; stroffset
    return {length: length
            offset: stroffset}
End Function

