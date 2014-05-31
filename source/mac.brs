'Sadly there is no way to get the MAC ourselves

Function get_mac(port as Object)
    sec = CreateObject("roRegistrySection", "trimeplay")
    For Each key In sec.GetKeyList()
        If key = "mac"
           print "Already have MAC: " ; sec.Read(key)
           return sec.Read(key)
        End If
    End For
    ' No mac is configured yet. Put up a screen

     dialog = CreateObject("roMessageDialog")
     dialog.SetMessagePort(port) 
     dialog.SetTitle("trimeplay needs your MAC address")
     dialog.SetText("To convince iOS7 devices that your Roku is really an AppleTV, trimeplay needs the MAC address currently in use by your Roku. You can get this information from the Settings menu item on the home screen of the Roku. Yes, I realise how stupid this is, but there is no way to get it out of the Roku from channels written by outsiders. Enter the MAC without : separators, for example ABCD01234567. This will be stored in the roku so you only have to enter it once. If you want to change the MAC, you will need to uninstall and reinstall trimeplay")
    dialog.AddButton(1, "OK")
    dialog.EnableBackButton(true)
    dialog.Show()
    While True
        dlgMsg = wait(0, dialog.GetMessagePort())
        print "message"
        If type(dlgMsg) = "roMessageDialogEvent"
            if dlgMsg.isButtonPressed()
                if dlgMsg.GetIndex() = 1
                    exit while
                end if
            else if dlgMsg.isScreenClosed()
                exit while
            end if
        end if
    end while 
     screen = CreateObject("roKeyboardScreen")

     screen.SetMessagePort(port)
     screen.SetTitle("Please enter your MAC address")
     screen.SetText("")
     screen.SetDisplayText("Enter without : separators")
     screen.SetMaxLength(12)
     screen.AddButton(1, "finished")
     screen.Show()
     while true
         msg = wait(0, screen.GetMessagePort())
         if type(msg) = "roKeyboardScreenEvent"
             if msg.isButtonPressed() then
                 if msg.GetIndex() = 1
                      sec = CreateObject("roRegistrySection", "trimeplay")
                      sec.Write("mac", screen.GetText())
                      sec.Flush()
                      screen.Close()
                      return screen.GetText()
                 End If
             End If
         End If
     end while 
End Function