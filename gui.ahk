#SingleInstance Force
#Include files.ahk


ListLines false
KeyHistory 0

globalGui := unset
globalDisplaySeconds := 0

nothing(*) {
}

display(x, sec := 3, followGui := false) {
    msg := repr(x)
    static displaying := ''
    displaying := displaying ? displaying '`n' msg : msg
    if followGui {
        ToolTip(displaying, 0, -14)
    } else {
        ToolTip(displaying)
    }
    if globalDisplaySeconds > 0 {
        sec := globalDisplaySeconds
    }
    SetTimer(() => (displaying := '', ToolTip()), -1000 * sec)
    return msg
}

makeGlobalGui(title?, font := 'consolas', fontOpt := 's10') {
    global globalGui
    if IsSet(globalGui) {
        globalGui.Destroy()
    }
    globalGui := makeGui(title?, exitGui)
    globalGui.SetFont(fontOpt, font)
    return globalGui
}

makeGui(title?, onEscape?) {
    g := Gui()
    if IsSet(title) {
        g.Title := title
    } else {
        g.Opt('-Caption')
    }
    if IsSet(onEscape) {
        g.OnEvent('Escape', onEscape)
        g.OnEvent('Close', onEscape)
    }
    return g
}

exitGui(g?, preAction?) {
    global globalGui
    if IsSet(preAction) {
        preAction(globalGui)
    }
    globalGui.Destroy()
    globalGui := unset
}

showGui() {
    globalGui.Show('AutoSize')
}

centerWindow() {
    WinGetPos(, , &width, &height, 'A')
    WinMove(A_ScreenWidth / 2 - width / 2, A_ScreenHeight / 2 - height / 2, , , 'A')
}

wrapCmd(gc, callback) {
    cmd() {
        msg := callback(gc)
        if msg {
            display(msg, 2, true)
            return
        }
    }
    return cmd
}

popupYesNo(title, text) {
    return MsgBox(text, title, 'YesNo') == 'Yes'
}

estimateLen(str) {
    static edgeMap := seqAll('│', '└', '┴', '─', '╪', '┼').toMapWith(Ord)
    return seqSplit(str, '').sum(c => Ord(c) < 128 or edgeMap.Has(c) ? 7.5 : 15)
}

listViewAll(titles, rows, guiMaker := makeGlobalGui, maxHeight := 30) {
    if rows.Length = 0 {
        throw ValueError('Empty list')
    }
    colNum := rows[1].Length
    if titles.Length != colNum {
        throw ValueError('Title length mismatched with columns (' titles.Length ' != ' colNum ')')
    }
    g := guiMaker()

    estColWidth(i) {
        maxBy(rows, &_, r => estimateLen(r[i]), &maxLen)
        return Max(maxLen, estimateLen(titles[i]))
    }
    width := 11 * colNum + range(1, colNum).sum(estColWidth)
    height := Min(rows.Length, maxHeight)
    if height < rows.Length {
        width += 11
    }
    lv := g.AddListView('NoSortHdr w' width ' r' height, titles)
    forEach(rows, row => lv.Add(, row*))

    lv.ModifyCol()
    lv.ModifyCol(colNum, 'AutoHdr')
    showGui()
    return lv
}

lvSelect(lv, i, positive := true) {
    lv.Modify(i, positive ? 'Select Focus' : '-Select -Focus')
}

lvGetAllSelected(lv) {
    fun() {
        j := 0
        return (&i) => i := j := lv.GetNext(j)
    }
    return EnumSeq(fun)
}

formatError(e) {
    return Type(e) ': ' e.Message (e.Extra ? ' (' e.Extra ')' : '')
}

execSelection() {
    expression := copySelection()
    if not expression {
        return
    }
    toStdOut(s) {
        return 'FileAppend(repr((' s ')), "*")'
    }
    if InStr(expression, '`n') {
        lines := StrSplit(expression, '`n', ' `t`r')
        for i in range(lines.Length, 1, -1) {
            if lines[i] {
                lines[i] := toStdOut(lines[i])
                break
            }
        }
        content := join(lines, '`n')
    } else {
        content := toStdOut(expression)
    }
    static shell := ComObject('WScript.Shell')
    exec := shell.Exec(A_AhkPath ' /ErrorStdOut *')
    script := Format("
    (
        #Warn All, Off
        #Include {1}
        try {
            {2}
        } catch Error as e {
            FileAppend(formatError(e), '*')
        }
        ExitApp
    )", A_ScriptFullPath, content)
    exec.StdIn.WriteLine(script)
    exec.StdIn.Close()
    return exec.StdOut.ReadAll()
}

toExe(name) {
    return 'ahk_exe ' name '.exe'
}

procName() {
    return SubStr(WinGetProcessName('A'), 1, -4)
}

gcGetWinId(gc, &id) {
    try {
        return id := 'ahk_id ' ControlGetHwnd(gc)
    } catch Error {
    }
}

isWinTitleMatch(pattern) {
    return isWildcardMatch(WinGetTitle('A'), pattern)
}

isWinActive(procName, titlePattern?) {
    return WinActive(toExe(procName)) and (
        not IsSet(titlePattern) or not titlePattern
        or isWinTitleMatch(titlePattern)
    )
}


#F5:: Reload
#F8:: doCopy(display(procName()))
#F9:: doCopy(display(WinGetTitle('A')))
#F12:: doCopy(display(execSelection()))


; listViewAll(['a', 'b', 'c'], [['jifdajifjdaijfjjijijif', 'fsdajifdajofjaosuff', 'jijfidajifjaifjiaufodiuafiufasof']])
; listViewAll(['a', 'b', 'c'], [['jifdajifjdaijfj', 'fsda', 'jijfidajifjaifjia']])
; listViewAll(['a', 'b', 'c'], [['jij', 'fsj', 'jij']])
; listViewAll(['a', 'b', 'c'], [['人间四月芳菲尽', '一蓑烟雨任平生', 'jijfidajifjaifjiaufodiuafiufasof']])
