' ********************************************************************
' **  riban Video App
' **  Copyright (c) 2014 riban. All Rights Reserved.
' ********************************************************************

Library "v30/bslCore.brs"

Sub Main()
    initTheme()
    
    screenFacade = CreateObject("roPosterScreen")
    screenFacade.show()

    regSettings = CreateObject("roRegistrySection", "Settings")
    if NOT regSettings.Exists("ServerUrl")
        showToast("Server not configured - please do so now")
        setServer()
    endif

    bRun = True
    while bRun
        showMenu()
        dialog = CreateObject("roMessageDialog")
        port = CreateObject("roMessagePort")
        dialog.SetMessagePort(port)
        dialog.SetTitle("Confirm exit")
        dialog.AddButton(0, "Cancel")
        dialog.AddButton(1, "Exit")
        dialog.EnableBackButton(True)
        dialog.SetText("Please confirm that you wish to exit video player")
        dialog.Show()
        msg = wait(0, port)
        dialog.Close()
        if type(msg) = "roMessageDialogEvent" AND msg.isButtonPressed() AND msg.GetIndex() = 1
            exit while
        end if
    end while
    'exit the app gently so that the screen doesn't flash to black
    screenFacade.showMessage("")
    sleep(25)
End Sub


Sub initTheme()

    app = CreateObject("roAppManager")
    theme = CreateObject("roAssociativeArray")

    theme.BackgroundColor = "#222222"
    theme.OverhangSliceHD = "pkg:/image/Overhang_BackgroundSlice_HD.png"
    theme.OverhangSliceSD = "pkg:/image/Overhang_BackgroundSlice_SD.png"
    app.SetTheme(theme)

End Sub

'**Get videos list from server
Function getVideos(mode as String) As object
    regSettings = CreateObject("roRegistrySection", "Settings")
    serverUrl = regSettings.Read("ServerUrl")
    http = CreateObject("roUrlTransfer")
    http.SetUrl(serverUrl + "bin/edit.php?get=" + mode)
    response = ParseJson(http.GetToString())
    
    if http.GetFailureReason() = invalid
        showToast("Failed to connect to server")
        return invalid
    endif

    contentList = CreateObject("roArray", 200, True)    
    if response <> invalid
            for each element in response.recordings
                urlStream = element.uri
                if urlStream <> invalid
                    if urlStream.Left(4) <> "http"
                        urlStream = serverUrl + urlStream
                    end if
                    urlIcon = element.icon
                    if urlIcon <> invalid AND urlIcon.Left(4) <> "http"
                        urlIcon = serverUrl + urlIcon
                    end if
                    format = element.format
                    if format = invalid
                        format = "mp4"
                    end if
                    quality = element.quality
                    if quality = invalid
                        quality = "SD"
                    end if
                    item = {
                        Title: element.title
                        StreamUrls: [urlStream]
                        StreamContentIDs: [element.uri]
                        ShortDescriptionLine1: element.summary
                        TitleSeason: element.summary
                        ShortDescriptionLine2: element.description
                        Description: element.description
                        HDPosterUrl: urlIcon
                        SDPosterUrl: urlIcon
                        ContentType: "video"
                        StreamBitrates: [0]
                        StreamQualities: [quality]
                        StreamFormat: format
                        PlayStart: element.position
                    }
                    contentList.Push(item)
                end if
            end for
    else
        print "Error parsing videos json"
        showToast("Error parsing videos list")
        return invalid
    end if

    return contentList
    
End Function

'** Show the main menu
Function showMenu()
    screen = CreateObject("roListScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    screen.SetBreadcrumbText("", "Main Menu")
    keycodes = bslUniversalControlEventCodes()
    screen.AddContent( {Title: "Videos"
                        ShortDescriptionLine1: "Show videos"
                        HDPosterUrl: "pkg:/images/film.png"
                        })
    screen.AddContent( {Title: "Live TV"
                        ShortDescriptionLine1: "Show live TV"
                        HDPosterUrl: "pkg:/images/tv.png"
                        })
    screen.AddContent( {Title: "Recycle Bin"
                        ShortDescriptionLine1: "Show videos pending deletion"
                        HDPosterUrl: "pkg:/images/recycle.png"
                        })
    screen.AddContent( {Title: "Settings"
                        ShortDescriptionLine1: "Adjust settings"
                        HDPosterUrl: "pkg:/images/settings.png"
                        })
    screen.AddContent( {Title: "Quit"
                        ShortDescriptionLine1: "Exit application"
                        HDPosterUrl: "pkg:/images/quit.png"
                        })
    screen.Show()
    
    while true
        msg = wait(0, port)
        if type(msg) = "roListScreenEvent"
            if msg.isScreenClosed()
                exit while
            else if msg.isListItemSelected()
                if msg.GetIndex() = 0
                    showVideos()
                else if msg.GetIndex() = 1
                    showTV()
                else if msg.GetIndex() = 2
                    showRecycle()
                else if msg.GetIndex() = 3
                    showSettings()
                else if msg.GetIndex() = 4
                    screen.Close()
                    exit while
                end if
           end if
        end if
    end while
End Function

'*************************************************************
'** showVideos
'** Display list of videos from server
'*************************************************************

Function showVideos() As Boolean
    contentList = getVideos("ready")
    if contentList = invalid OR contentList.IsEmpty()
        showToast("No Videos")
        return false
    end if

    screen = CreateObject("roListScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    screen.ClearContent()
    screen.SetBreadcrumbText("", "Videos")
    keycodes = bslUniversalControlEventCodes()

    back_item = {
        Title: "Back"
        ShortDescriptionLine1: "Return to main menu"
        HDPosterUrl: "pkg:/images/back.png"
        ContentType: "menu_back"
    }

    contentList.Push(back_item)
    screen.SetContent(contentList)
    selectedItem = 0
    regVideos = CreateObject("roRegistrySection", "Videos")
    if regVideos.Exists("SelectedItem") 
         selectedItem = regVideos.Read("SelectedItem").toInt()
    end if
    if selectedItem > contentList.Count() - 1
        selectedItem = contentList.Count() - 1
    end if
    screen.SetFocusedListItem(selectedItem)
        
    screen.Show()

    while true
        'TODO Check for updates to videos
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roListScreenEvent"
            if msg.isScreenClosed()
                exit while
            else if msg.isListItemFocused()
                selectedItem = msg.GetIndex()
            else if msg.isListItemSelected()
                selectedItem = msg.GetIndex()
                if(contentList[selectedItem].ContentType = "menu_back")
                    screen.Close()
                    exit while
                endif
                showDetail(contentList[selectedItem])
                'Update list
                contentList = getVideos("ready")
                if(contentList = invalid OR contentList.IsEmpty())
                    screen.Close()
                    showToast("No more videos")
                else
                    screen.SetContent(contentList)
                    if (selectedItem > contentList.Count() - 1) AND (selectedItem > 0) 
                        selectedItem = contentList.Count() - 1
                    end if
                    screen.SetFocusedListItem(selectedItem)
                    screen.Show()
                end if
            else if msg.isRemoteKeyPressed()
                if msg.GetIndex() = keycodes.BUTTON_PLAY_PRESSED
                    playVideo(contentList[selectedItem], True)
                    'Update list
                    contentList = getVideos("ready")
                    screen.SetContent(contentList)
                    if selectedItem > contentList.Count() - 1
                        selectedItem = contentList.Count() - 1 'TODO Check what happens if count is zero so selection becomes -1
                    end if
                    screen.SetFocusedListItem(selectedItem)
                    screen.Show()
                else if msg.GetIndex() = keycodes.BUTTON_RIGHT_PRESSED
                    'Page down
                    if selectedItem < contentList.Count() - 6
                        screen.SetFocusedListItem(selectedItem + 6)
                    else
                        screen.SetFocusedListItem(contentList.Count() - 1)                
                    endif
                else if msg.GetIndex() = keycodes.BUTTON_LEFT_PRESSED
                    'Page up
                    if selectedItem > 6
                        screen.SetFocusedListItem(selectedItem - 6)
                    else
                        screen.SetFocusedListItem(0)
                    endif
                else if msg.GetIndex() = keycodes.BUTTON_INFO_PRESSED
                    nameList = CreateObject("roArray", 200, True)
                    for each item in contentList
                        nameList.Push(item.Title)
                    end for
                    searchResult = showSearch(nameList)
                    if searchResult <> ""
                        nItem = 0
                        for each item in contentList
                            if item.Title = searchResult
                                screen.SetFocusedListItem(nItem)
                                exit for
                            end if
                            nItem = nItem + 1
                        end for
                    end if
                endif
            else
                print "showVideos: Unhandled roListScreenEvent: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        else 
            print "showVideos: Unhandled event type: type=";msg.GetType(); " msg: "; msg.GetMessage()
        endif
    end while

    regVideos = CreateObject("roRegistrySection", "Videos")
    regVideos.Write("SelectedItem", selectedItem.ToStr())
    regVideos.Flush()

    return true
End Function


'** Show list of videos marked for deletiong
Function showRecycle() As Boolean
    contentList = getVideos("delete")
    if contentList = invalid OR contentList.IsEmpty()
        showToast("No deleted videos")
        return false
    end if

    screen = CreateObject("roListScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    screen.ClearContent()
    screen.SetBreadcrumbText("", "Recycle Bin")
    screen.SetHeader("Recycle Bin")
    keycodes = bslUniversalControlEventCodes()
    selectedItem = 0

    screen.SetContent(contentList)
    screen.Show()

    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roListScreenEvent"
            if msg.isScreenClosed()
                exit while
            else if msg.isListItemFocused()
                selectedItem = msg.GetIndex()
            else if msg.isListItemSelected()
                selectedItem = msg.GetIndex()
                showDetail(contentList[selectedItem], true)
                'Update list
                contentList = getVideos("delete")
                if(contentList = invalid OR contentList.IsEmpty())
                    screen.Close()
                    showToast("Recycle bin empty")
                else
                    screen.SetContent(contentList)
                    if (selectedItem > contentList.Count() - 1) AND (selectedItem > 0) 
                        selectedItem = contentList.Count() - 1
                    end if
                    screen.SetFocusedListItem(selectedItem)
                    screen.Show()
                end if
            else if msg.isRemoteKeyPressed()
                if msg.GetIndex() = keycodes.BUTTON_PLAY_PRESSED
                    playVideo(contentList[selectedItem], True)
                    'Update list
                    contentList = getVideos("delete")
                    screen.SetContent(contentList)
                    if selectedItem > contentList.Count() - 1
                        selectedItem = contentList.Count() - 1
                    end if
                    screen.SetFocusedListItem(selectedItem)
                    screen.Show()
                else if msg.GetIndex() = keycodes.BUTTON_RIGHT_PRESSED
                    'Page down
                    if selectedItem < contentList.Count() - 6
                        screen.SetFocusedListItem(selectedItem + 6)
                    else
                        screen.SetFocusedListItem(contentList.Count() - 1)                
                    endif
                else if msg.GetIndex() = keycodes.BUTTON_LEFT_PRESSED
                    'Page up
                    if selectedItem > 6
                        screen.SetFocusedListItem(selectedItem - 6)
                    else
                        screen.SetFocusedListItem(0)
                    endif
                endif
            else
                print "showRecycle: Unhandled roListScreenEvent: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        else 
            print "showRecycle: Unhandled event type: type=";msg.GetType(); " msg: "; msg.GetMessage()
        endif
    end while

    return true
End Function

'*************************************************************
'** playVideo()
'** Play the requested video
'*************************************************************

Function playVideo(videoclip as Object, resume = True as boolean)
    if videoclip = invalid
        print "Invalid video object"
        return 0
    endif
    print "Playing video " videoclip.StreamUrls[0]
    port = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(port)

    regSettings = CreateObject("roRegistrySection", "Settings")
    serverUrl = regSettings.Read("ServerUrl")

    regVideos = CreateObject("roRegistrySection", "Videos")
'    if resume AND regVideos.Exists(videoclip.StreamUrls[0])
'        print "Setting start position to " regVideos.Read(videoclip.StreamUrls[0])
'        videoclip.playStart = regVideos.Read(videoclip.StreamUrls[0]).toInt()
'    else
    if NOT resume
        videoclip.PlayStart = 0
    endif

    video.SetContent(videoclip)
    video.SetPositionNotificationPeriod(1)
    video.Show()
    print videoclip
    
    playPosition = 0

    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then 'ScreenClosed event
                exit while
            else if msg.isPlaybackPosition()
                playPosition = msg.GetIndex()
            else if msg.isPartialResult()
                'Seem to get this when video is stopped so save current position
'                regVideos = CreateObject("roRegistrySection", "Videos")
'                regVideos.Write(videoclip.StreamUrls[0], playPosition.toStr())
                videoclip.PlayStart = playPosition
                http = CreateObject("roUrlTransfer")
                http.SetUrl(serverUrl + "bin/edit.php?update=" + videoclip.StreamContentIDs[0] + "&pos=" + playPosition.toStr())
                result = http.GetToString()
                print "Saving position " playPosition.toStr()
            else if msg.isFullResult()
                'Playback finished at end of item
'                regVideos = CreateObject("roRegistrySection", "Videos")
'                regVideos.Write(videoclip.StreamUrls[0], "0")
                videoClip.PlayStart = 0
                http = CreateObject("roUrlTransfer")
                http.SetUrl(serverUrl + "bin/edit.php?update=" + videoClip.StreamContentIDs[0] + "&pos=0")
                result = http.GetToString()
                print "End of video - saving position 0"
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
            else
                print "playVideo: Unhandled roVideoScreenEvent: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while
End Function

Function showDetail(item as object, bDeleted = false as boolean)
    if(item = invalid)
        return 0
    end if
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")
    screen.SetMessagePort(port) 
    screen.AllowUpdates(false)
    screen.SetContent(item)
    screen.ClearButtons()
    screen.AddButton(1, "Resume")
    screen.AddButton(2, "Play")
    if(bDeleted)
        screen.AddButton(3, "Restore")
    else
        screen.AddButton(3, "Delete")
    end if
    screen.AddButton(4, "Back")
    screen.SetStaticRatingEnabled(false)
    screen.SetPosterStyle("rounded-square-generic")
    screen.SetBreadcrumbText("", item.Title)
    screen.AllowUpdates(true)
'    screen.SetTitle(item.Title)
    
    screen.Show() 
    While True
        msg = wait(0, port)
        if Type(msg) = "roSpringboardScreenEvent"
            if msg.isScreenClosed()
                return -1
            else if msg.isButtonPressed() 
                if msg.GetIndex() = 1
                    print "Resume pressed"
                    playVideo(item, True)
                else if msg.GetIndex() = 2
                    print "Play pressed"
                    playVideo(item, False)
                else if msg.GetIndex() = 3
                    if(bDeleted)
                        print "Restore item with uri " item.StreamContentIDs[0]
                        regSettings = CreateObject("roRegistrySection", "Settings")
                        serverUrl = regSettings.Read("ServerUrl")
                        http = CreateObject("roUrlTransfer")
                        http.SetUrl(serverUrl + "bin/edit.php?restore=" + item.StreamContentIDs[0])
                        result = http.GetToString()
                        screen.Close()                                            
                    else
                        print "Delete pressed"
                        dialog = CreateObject("roMessageDialog")
                        dialog.SetMessagePort(port)
                        dialog.SetTitle("Confirm deletion")
                        dialog.AddButton(0, "Cancel")
                        dialog.AddButton(1, "Delete")
                        dialog.EnableBackButton(True)
                        dialog.SetText("Please confirm that you wish to delete this recording: " + chr(10) + chr(10) + item.Title)
                        dialog.Show()
                    end if
                else if msg.GetIndex() = 4
                    screen.Close()
                    exit while
                end if
            endif
        else if Type(msg) = "roMessageDialogEvent"
            if msg.isButtonPressed()
                print "Dialog button pressed"
                if msg.GetIndex() = 1
                    print "Removing item with url " item.StreamContentIDs[0]
                    regSettings = CreateObject("roRegistrySection", "Settings")
                    serverUrl = regSettings.Read("ServerUrl")
                    http = CreateObject("roUrlTransfer")
                    http.SetUrl(serverUrl + "bin/edit.php?delete=" + item.StreamContentIDs[0])
                    result = http.GetToString()
                    dialog.Close()
                    screen.Close()
                else
                    dialog.Close()
                endif
            endif
        endif
    End While
End Function

Function showSettings()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roListScreen")
    screen.SetMessagePort(port) 
    screen.SetBreadcrumbText("", "Settings")
    regSettings = CreateObject("roRegistrySection", "Settings")
    serverUrl = regSettings.Read("ServerUrl")
    keycodes = bslUniversalControlEventCodes()
    screen.AddContent( {Title: "Set Server"
                        ShortDescriptionLine1: "Set the server URI: " + serverUrl
                        HDPosterUrl: "pkg:/images/settings.png"
                        })
    screen.AddContent( {Title: "Clear registry"
                        ShortDescriptionLine1: "Clears all registry entires"
                        HDPosterUrl: "pkg:/images/settings.png"
                        })
    screen.Show()
    
    while true
        msg = wait(0, port)
        if type(msg) = "roListScreenEvent"
            if msg.isScreenClosed()
                return 0
            else if msg.isListItemSelected()
                print "Selected menu item " msg.GetIndex()
                if msg.GetIndex() = 0
                    setServer()
                else if msg.GetIndex() = 1
                    if showConfirm("Reset all settings - clearing registry")
                        reg = CreateObject("roRegistry")
                        reg.Delete("Settings")
                        reg.Delete("Videos")
                    end if
                end if
            end if
        end if
    end while
End Function

Function setServer()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roKeyboardScreen")
    screen.SetMessagePort(port)
    screen.SetTitle("Server URL")
    screen.SetDisplayText("Enter url of server, e.g. http://myserver/pvr/")
    regSettings = CreateObject("roRegistrySection", "Settings")
    if regSettings.Exists("ServerUrl")
        serverUrl = regSettings.Read("ServerUrl")
    else
        serverUrl = "http://"
    endif
    screen.SetText(serverUrl)
    screen.AddButton(0, "Cancel")
    screen.AddButton(1, "OK")
    screen.Show()
    
    while true
        msg = wait(0, port)
        if type(msg) = "roKeyboardScreenEvent"
            if msg.isScreenClosed()
                return 0
            else if msg.isButtonPressed()
                if msg.getIndex() = 1
                    serverUrl = screen.GetText()
                    if Right(serverUrl, 1) <> "/"
                        serverUrl = serverUrl + "/"
                    endif
                    regSettings.Write("ServerUrl", serverUrl)
                endif
                screen.Close()
            end if
        end if
    end while
End Function

Function showTV()
    showToast("Live TV not yet implemented")
End Function

Function showToast(title as string)
    dialog = CreateObject("roOneLineDialog")
    dialog.SetTitle(title)
    dialog.Show()
    sleep(2000)
    dialog.Close()
End Function

Function showConfirm(title as string) as Boolean
    port = CreateObject("roMessagePort")
    dialog = CreateObject("roMessageDialog")
    dialog.SetMessagePort(port)
    dialog.SetTitle("Please confirm...")
    dialog.AddButton(0, "Cancel")
    dialog.AddButton(1, "Confirm")
    dialog.EnableBackButton(True)
    dialog.SetText(title)
    dialog.Show()

    while true
        msg = wait(0, port)
        if Type(msg) = "roMessageDialogEvent"
            if msg.isScreenClosed()
                return false
            else if msg.isButtonPressed()
                if msg.GetIndex() = 1
                    dialog.Close()
                    return true
                else
                    dialog.Close()
                    return false
                endif
            endif
        endif
    end while
    return false 'should never get here but just in case...
End Function

Function showVideosOptions()
    port = CreateObject("roMessagePort")
    dialog = CreateObject("roMessageDialog")
    dialog.SetMessagePort(port)
    dialog.SetTitle("Videos Options")
    dialog.AddButton(0, "Cancel")
    dialog.AddButton(1, "Search")
    dialog.EnableBackButton(True)
    dialog.Show()
    
    while true
        msg = wait(0, port)
        if Type(msg) = "roMessageDialogEvent"
            if msg.GetIndex() = 0
                dialog.Close()
                return 0
            else if msg.GetIndex() = 1
'                showSearch()
            end if
        end if
    end while
End Function

Function showSearch(searchTerms as Object) as String
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSearchScreen")
    screen.SetMessagePort(port)
    screen.SetSearchTerms(searchTerms)
    screen.SetSearchTermHeaderText("Suggestions:")
    screen.SetSearchButtonText("search")
    screen.SetClearButtonEnabled(false)
    screen.Show()
    
    while true
        msg = wait(0, port)
        if Type(msg) = "roSearchScreenEvent"
            if msg.isScreenClosed()
                exit while
            else if msg.isPartialResult()
                results = CreateObject("roArray", 200, true)
                for each item in searchTerms
                    if (LCase(item).instr(msg.GetMessage()) > -1)
                        results.Push(item)
                    endif
                end for
                screen.SetSearchTerms(results)
            else if msg.isFullResult()
                return msg.GetMessage()
            endif
        end if
    end while
    return ""
End Function
