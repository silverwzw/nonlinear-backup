#SingleInstance Force
#Include files.ahk
#Include strings.ahk


globalGui := unset
globalDisplaySeconds := 0
displaying := unset

nothing(*) {
}

display(msg, sec := 3, followGui := false, copy := false) {
    global displaying
    displaying := IsSet(displaying) ? displaying '`n' msg : msg
    if followGui {
        ToolTip(displaying, 0, -14)
    } else {
        ToolTip(displaying)
    }
    t := -1000 * (globalDisplaySeconds > 0 ? globalDisplaySeconds : sec)
    SetTimer(() => (displaying := unset, ToolTip()), t)
    if copy {
        A_Clipboard := msg
    }
}

displayAll(sec, msg*) {
    display(join(msg, '`n'), sec)
}

makeGlobalGui(title?, font := 'consolas', fontOpt := 's10') {
    global globalGui
    if IsSet(globalGui) {
        globalGui.Destroy()
    }
    globalGui := IsSet(title) ? makeGui(title, exitGui) : makeGui(, exitGui)
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
    }
    return g
}

_destroyGui(g) {
    g.Destroy()
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
    WinMove((A_ScreenWidth / 2) - (width / 2), (A_ScreenHeight / 2) - (height / 2), , , 'A')
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

edgeMap := seqAll('│', '└', '┴', '─', '╪', '┼').toMapWith(Ord)

estimateLen(str) {
    return aSum(StrSplit(str), c => Ord(c) < 128 or edgeMap.Has(c) ? 7.5 : 15)
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
        aMaxBy(rows, &_, r => estimateLen(r[i]), &maxLen)
        return Max(maxLen, estimateLen(titles[i]))
    }
    width := 11 * colNum + aSum(range(1, colNum), estColWidth)
    height := Min(rows.Length, maxHeight)
    if height < rows.Length {
        width += 11
    }
    lv := g.AddListView('+NoSortHdr w' width ' r' height, titles)
    forEach(rows, row => lv.Add(, row*))

    lv.ModifyCol()
    lv.ModifyCol(colNum, 'AutoHdr')
    lvSelect(lv, 1)
    showGui()
    return lv
}

lvSelect(lv, i) {
    lv.Modify(i, 'Focus')
    lv.Modify(i, 'Select')
}

lvUnSelect(lv, i) {
    lv.Modify(i, '-Focus')
    lv.Modify(i, '-Select')
}

lvGetAllSelected(lv) {
    fun(c) {
        loop {
            i := lv.GetNext()
            if i == 0 {
                break
            }
            c(i)
            lvUnSelect(lv, i)
        }
    }
    return Seq(fun).toArray()
}

toExe(name) {
    return 'ahk_exe ' name '.exe'
}

procName() {
    return SubStr(WinGetProcessName('A'), 1, -4)
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
#F8:: display(procName())
#F9:: display(WinGetTitle('A'))

; listViewAll(['a', 'b', 'c'], [['jifdajifjdaijfjjijijif', 'fsdajifdajofjaosuff', 'jijfidajifjaifjiaufodiuafiufasof']])
; listViewAll(['a', 'b', 'c'], [['jifdajifjdaijfj', 'fsda', 'jijfidajifjaifjia']])
; listViewAll(['a', 'b', 'c'], [['jij', 'fsj', 'jij']])
; listViewAll(['a', 'b', 'c'], [['人间四月芳菲尽', '一蓑烟雨任平生', 'jijfidajifjaifjiaufodiuafiufasof']])
