#Include files.ahk
#Include arrays.ahk


globalGui := unset
globalDisplaySeconds := 0
displaying := unset
onEnterCmd := nothing
onShiftUpCmd := nothing
onShiftDownCmd := nothing
onShiftDelCmd := nothing
ahkWin := toExe('AutoHotkey64')


display(msg, sec := 3, followGui := false, copy := false) {
    global displaying
    displaying := IsSet(displaying) ? displaying '`n' msg : msg
    if followGui {
        ToolTip(displaying, 0, -22)
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

makeGui(fontOpt := 's10', font := 'consolas') {
    global globalGui
    if IsSet(globalGui) {
        globalGui.Destroy()
    }
    globalGui := Gui()
    globalGui.SetFont(fontOpt, font)
    globalGui.OnEvent('Escape', g => exitGui())
    globalGui.Opt('-Caption')
    return globalGui
}

nothing(*) {
}

setOnEnter(cmd) {
    global onEnterCmd
    onEnterCmd := cmd
}

setOnShiftUp(cmd) {
    global onShiftUpCmd
    onShiftUpCmd := cmd
}

setOnShiftDown(cmd) {
    global onShiftDownCmd
    onShiftDownCmd := cmd
}

setOnShiftDel(cmd) {
    global onShiftDelCmd
    onShiftDelCmd := cmd
}

exitGuiWith(msg, sec) {
    exitGui(g => display(msg, sec, true))
}

exitGui(preAction?) {
    if IsSet(preAction) {
        preAction(globalGui)
    }
    global globalGui, onEnterCmd, onShiftUpCmd, onShiftDownCmd, onShiftDelCmd
    globalGui.Destroy()
    globalGui := unset
    onEnterCmd := nothing
    onShiftUpCmd := nothing
    onShiftDownCmd := nothing
    onShiftDelCmd := nothing
}

showGui() {
    globalGui.Show('AutoSize')
}

centerWindow() {
    WinGetPos(, , &width, &height, 'A')
    WinMove((A_ScreenWidth / 2) - (width / 2), (A_ScreenHeight / 2) - (height / 2), , , 'A')
}

gcWrapCmd(gc, callback) {
    cmd() {
        msg := callback(gc)
        if msg {
            display(msg, 1, true)
            return
        }
    }
    return cmd
}

readInput(guiMaker := makeGui, editOpt := 'r1 w300', defaultText := '', onEnter?) {
    g := guiMaker()
    gc := g.AddEdit(editOpt, defaultText)
    if IsSet(onEnter) {
        setOnEnter(gcWrapCmd(gc, onEnter))
    }
    showGui()
}

listAll(a, guiMaker := makeGui, destroyOnConfirm := true, onEnter := display) {
    if a.Length = 0 {
        throw MethodError('Empty list')
    }
    g := guiMaker()
    amaxBy(a, &_, StrLen, &maxLen)
    width := 12 * (maxLen + 1)
    box := g.AddListBox('w' width ' r' a.Length, a)
    box.Choose(1)
    onConfirm(gc, index) {
        onEnter(index)
        if destroyOnConfirm {
            exitGui()
        }
    }
    box.OnEvent('DoubleClick', onConfirm)
    showGui()
}

edgeMap := Seq.all('│', '└', '┴', '─', '╪', '┼').toMapWith(Ord)

estimateLen(str) {
    return asum(StrSplit(str), c => Ord(c) < 128 or edgeMap.Has(c) ? 7.5 : 15)
}

listViewAll(titles, rows, guiMaker := makeGui, onEnter?, onShiftUp?, onShiftDown?, onShiftDel?) {
    if rows.Length = 0 {
        throw ValueError('Empty list')
    }
    colNum := rows[1].Length
    if titles.Length != colNum {
        throw ValueError('Title length mismatched with columns (' titles.Length ' != ' colNum ')')
    }
    g := guiMaker()

    estColWidth(i) {
        amaxBy(rows, &_, r => estimateLen(r[i]), &maxLen)
        return Max(maxLen, estimateLen(titles[i]))
    }
    width := 11 * colNum + asum(range(1, colNum), estColWidth)
    height := Min(rows.Length, 30)
    if height < rows.Length {
        width += 5
    }
    lv := g.AddListView('-Multi +NoSortHdr w' width ' r' height, titles)
    forEach(rows, row => lv.Add(, row*))

    lv.ModifyCol()
    lv.ModifyCol(colNum, 'AutoHdr')
    lvSelect(lv, 1)

    if IsSet(onEnter) {
        setOnEnter(gcWrapCmd(lv, onEnter))
    }
    if IsSet(onShiftUp) {
        setOnShiftUp(gcWrapCmd(lv, onShiftUp))
    }
    if IsSet(onShiftDown) {
        setOnShiftDown(gcWrapCmd(lv, onShiftDown))
    }
    if IsSet(onShiftDel) {
        setOnShiftDel(gcWrapCmd(lv, onShiftDel))
    }
    showGui()
}

lvSelect(lv, i) {
    lv.Modify(i, 'Focus')
    lv.Modify(i, 'Select')
}

toExe(name) {
    return 'ahk_exe ' name '.exe'
}

procName() {
    return SubStr(WinGetProcessName('A'), 1, -4)
}


#HotIf WinActive(toExe('AutoHotkey64'))
Enter:: onEnterCmd()
+Up:: onShiftUpCmd()
+Down:: onShiftDownCmd()
+Del:: onShiftDelCmd()
#HotIf


#F5:: Reload
#F8:: display(procName())


; listViewAll(['a', 'b', 'c'], [['jifdajifjdaijfjjijijif', 'fsdajifdajofjaosuff', 'jijfidajifjaifjiaufodiuafiufasof']])
; listViewAll(['a', 'b', 'c'], [['jifdajifjdaijfj', 'fsda', 'jijfidajifjaifjia']])
; listViewAll(['a', 'b', 'c'], [['jij', 'fsj', 'jij']])
; listViewAll(['a', 'b', 'c'], [['吃饭喝水荡秋千', '人人都是大坏蛋', 'jijfidajifjaifjiaufodiuafiufasof']])
