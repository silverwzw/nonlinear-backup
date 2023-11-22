#Include files.ahk
#Include arrays.ahk

ahk := false
py := false
fcs := false
singleGui := unset
displaying := unset
globalDisplaySeconds := 0
onEnterCmd := nothing
ahkWin := toExe('AutoHotkey64')


display(msg, sec := 3, copy := false, followGui := false) {
    global displaying
    displaying := IsSet(displaying) ? displaying '`n' msg : msg
    if followGui {
        ToolTip(displaying, 0, 15)
    } else {
        ToolTip(displaying)
    }
    t := -1000 * (globalDisplaySeconds > 0 ? globalDisplaySeconds : sec)
    SetTimer(() => (displaying := unset, ToolTip()), t)
    if copy
        A_Clipboard := msg
}

displayAll(sec, msg*) {
    display(join(msg, '`n'), sec)
}

makeGui(fontOpt := 's10', font := 'consolas') {
    global singleGui
    if IsSet(singleGui) {
        singleGui.Destroy()
    }
    singleGui := Gui()
    singleGui.SetFont(fontOpt, font)
    singleGui.OnEvent('Escape', destroyGui)
    singleGui.Opt('-Caption')
    return singleGui
}

nothing(*) {
}

setOnEnter(cmd) {
    global onEnterCmd
    onEnterCmd := cmd
}

destroyGui(*) {
    singleGui.Destroy()
    global onEnterCmd
    onEnterCmd := nothing
}

showGui() {
    singleGui.Show('AutoSize')
}

centerWindow() {
    WinGetPos(, , &width, &height, 'A')
    WinMove((A_ScreenWidth / 2) - (width / 2), (A_ScreenHeight / 2) - (height / 2), , , 'A')
}

readInput(guiMaker := makeGui, editOpt := 'r1 w300', defaultText := '', onEnter := display) {
    g := guiMaker()
    gc := g.AddEdit(editOpt, defaultText)
    enterCmd(*) {
        text := gc.Value
        msg := onEnter(text)
        if msg {
            display(msg, 1, , true)
        } else {
            destroyGui()
        }
    }
    setOnEnter(enterCmd)
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
            destroyGui()
        }
    }
    box.OnEvent('DoubleClick', onConfirm)
    showGui()
}

edgeMap := Seq.all('│', '└', '┴', '─', '╪', '┼').toMapWith(Ord)

estimateLen(str) {
    return asum(StrSplit(str), c => Ord(c) < 128 or edgeMap.Has(c) ? 7.5 : 15)
}

listViewAll(titles, rows, guiMaker := makeGui, destroyOnConfirm := true, onEnter?, onDoubleClick?) {
    if rows.Length = 0 {
        throw ValueError('Empty list')
    }
    colNum := rows[1].Length
    if titles.Length != colNum {
        throw ValueError('title length mismatched with columns (' titles.Length ' != ' colNum ')')
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
    lv.Modify(1, 'Focus')
    lv.Modify(1, 'Select')

    onEnterCmd() {
        if IsSet(onEnter) {
            msg := onEnter(lv.GetNext())
            if msg {
                display(msg, 1)
                return
            }
        }
        if destroyOnConfirm {
            destroyGui()
        }
    }
    if IsSet(onEnter) {
        setOnEnter(onEnterCmd)
    }
    if IsSet(onDoubleClick) {
        lv.OnEvent('DoubleClick', onDoubleClick)
    }
    showGui()
}

configMode() {
    g := makeGui()
    width := 'w200'

    addModeBox(name, var, toggler) {
        box := g.AddCheckbox(checkboxOpt(width, var), name)
        box.OnEvent('Click', toggler)
    }

    global ahk
    addModeBox('ahk mode', ahk, (*) => ahk := !ahk)

    global py
    addModeBox('python mode', py, (*) => py := !py)

    global fcs
    addModeBox('chrome focus mode', fcs, (*) => fcs := !fcs)

    showGui()
}

checkboxOpt(origin, isChecked) {
    return isChecked ? origin ' checked' : origin
}

toExe(name) {
    return 'ahk_exe ' name '.exe'
}

procName() {
    return SubStr(WinGetProcessName('A'), 1, -4)
}


#HotIf WinActive(toExe('AutoHotkey64'))
Enter:: onEnterCmd()
#HotIf


#F5:: Reload
#F8:: display(procName())


; listViewAll(['a', 'b', 'c'], [['jifdajifjdaijfjjijijif', 'fsdajifdajofjaosuff', 'jijfidajifjaifjiaufodiuafiufasof']])
; listViewAll(['a', 'b', 'c'], [['jifdajifjdaijfj', 'fsda', 'jijfidajifjaifjia']])
; listViewAll(['a', 'b', 'c'], [['jij', 'fsj', 'jij']])
; listViewAll(['a', 'b', 'c'], [['吃饭喝水荡秋千', '人人都是大坏蛋', 'jijfidajifjaifjiaufodiuafiufasof']])
