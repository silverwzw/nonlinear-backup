#SingleInstance Force
#Include gui.ahk


appName := '非线性备份'
cmdMap := seqAll('Enter', 'CtrlUp', 'CtrlDown', 'Del', 'RButton').toMapWith(name => nothing)

checkTimeFormat(time) {
    if not isFullMatch(time, '[0-9]{14}') {
        throw ValueError('illegal time format: ' time)
    }
}

timeEncode(time) {
    checkTimeFormat(time)
    return sys60Encode(Integer(SubStr(time, 2)))
}

timeDecode(encoding) {
    if not encoding {
        return ''
    }
    s := String(sys60Decode(encoding))
    len := StrLen(s)
    return len == 12 ? '20' s : (len == 13 ? '2' s : s)
}

readableTime(time) {
    if not time {
        return ''
    }
    checkTimeFormat(time)
    return FormatTime(time, "yyyyMMdd HH:mm:ss")
}

quit(msg) {
    display(msg)
    SetTimer(ExitApp, -2900)
}

backupIni := 'backup.ini'
if not FileExist(backupIni) {
    quit('同目录下缺失"' backupIni '"文件')
    return
}

accumulator(dirMap, line) {
    if startsWith(line, ';') {
        return
    }
    a := StrSplit(line, '=', ' ', 2)
    if a.Length != 2 {
        quit('语法错误：' line)
        stop()
    }
    a2 := StrSplit(a[2], ',', ' ', 2)
    if not FileExist(a2[1]) {
        quit('存档路径不存在：' a[2])
        stop()
    }
    a1 := StrSplit(a[1], ',', ' ', 2)
    dirMap[a1[1]] := [aGetOr(a1, 2, ''), a2[1], aGetOr(a2, 2, '*')]
}

procDirMap := seqReadlines(backupIni).reduce(Map(), accumulator)
if procDirMap.Count == 0 {
    quit('无存档配置')
    return
}

backupDir := A_WorkingDir


exitGuiWith(msg, sec) {
    exitGui(, g => display(msg, sec, true))
    for k in cmdMap {
        cmdMap[k] := nothing
    }
}

class BackupHelper {
    __New(proc, src, filePattern) {
        this.proc := proc
        this.src := src
        this.filePattern := filePattern
        this.target := backupDir '\' proc
        this.saves := scanFilesLatest(this.target, , 'D').map(fileName).toArray()
        this.entries := aMap(this.saves, f => StrSplit(f, '#'))
        this.entries.Push(['', '', '[双击打开路径]'])
        this.head := scanFiles(this.target).findMaybe(f => not fileExt(f)).mapOr(fileName, '')
    }

    saveFiles() {
        g := makeGlobalGui(appName, '微软雅黑')
        gc := g.AddEdit('r1 w300', '新建备份')
        showGui()

        onEnter(ed) {
            saveName := ed.Value
            if isFullMatch(saveName, '\s*') {
                return '不允许空文件夹'
            }
            if hasMatch(saveName, '[\\/:*?"<>|]') {
                return '不能包含非法字符`n\/:*?"<>|'
            }
            srcFiles := scanFiles(this.src, this.filePattern).cache()
            if not srcFiles.map(fileModifiedTime).max(&latestTime) {
                return '无可备份文件'
            }
            timestamp := timeEncode(latestTime)
            for i, e in this.entries {
                if e[1] == timestamp {
                    if popupYesNo('重命名存档', '已有最新存档: ' e[3] '`n是否重命名') {
                        this.renameSave(this.saves[i], e[1], e[2], saveName)
                        exitGuiWith(saveName ' - 已重命名', 3)
                    }
                    return
                }
            }
            if anyMatch(this.entries, e => e[3] == saveName) {
                return '存档已存在'
            }
            folder := timestamp '#' this.head '#' saveName
            filesBackup(this.target, folder, srcFiles.map(filePath))
            if this.head {
                FileMove(this.target '\' this.head, this.target '\' timestamp)
            } else {
                FileAppend('', this.target '\' timestamp)
            }
            exitGuiWith(saveName ' - 已保存', 3)
        }
        cmdMap['Enter'] := wrapCmd(gc, onEnter)
    }

    showSaves(selections*) {
        size := this.entries.Length
        if size <= 1 {
            display('暂无备份')
            return
        }
        bad := seqOf(this.entries).filter(e => e.Length < 3).map(e => e[1]).toArray()
        if bad.Length > 0 {
            if popupYesNo('归档确认', '发现以下未归档备份：`n`n'
                join(bad, '`n', f => '- ' f) '`n`n'
                '是否统一归档(Y)或删除(N)`n'
                '归档后将按时间顺序视为连续继承')
            {
                seqReverse(bad).fold('', (parent, folder) => (
                    id := timeEncode(FileGetTime(this.target '\' folder)),
                    this.renameSave(folder, id, parent, folder),
                    id
                ))
                msg := '备份已归档'
            } else {
                for folder in bad {
                    DirDelete(this.target '\' folder, true)
                }
                msg := '已删除未归档备份'
            }
            this.updateSaves()
            display(msg, 3, true)
            return
        }
        nodeIndexMap := Map()
        forEachIndexed(this.entries, (i, e) => nodeIndexMap[e[1]] := i)
        parentMap := range(1, size - 1).toMapWith(i => nodeIndexMap.Get(this.entries[i][2], size))
        childrenMap := range(1, size - 1).groupBy(i => parentMap[i], i => i)
        tree := aRepeatBy(size, () => aRepeat(size, ' '))

        foundHead := false
        fillNode(i, j) {
            if not foundHead and this.entries[i][1] == this.head {
                foundHead := true
                tree[i][j] := '╪'
            } else {
                tree[i][j] := '┼'
            }
            if not childrenMap.Has(i) {
                return j
            }
            children := childrenMap[i]
            first := children[1]
            for k in range(first + 1, i - 1) {
                tree[k][j] := '│'
            }
            end := fillNode(first, j)
            count := children.Length
            for cIndex in range(2, count) {
                for k in range(j + 1, end) {
                    tree[i][k] := '─'
                }
                j := end + 1
                tree[i][j] := cIndex < count ? '┴' : '└'
                c := children[cIndex]
                for k in range(c + 1, i - 1) {
                    tree[k][end + 1] := '│'
                }
                end := fillNode(c, end + 1)
            }
            return end
        }
        end := fillNode(size, 1)

        beautifyRow(row) {
            a := aRepeat((end << 1) - 1, ' ')
            for i in range(1, end) {
                s := row[i]
                a[(i << 1) - 1] := s
                if s == '└' or s == '┴' or s == '─' {
                    a[(i << 1) - 2] := '─'
                }
            }
            return seqReverse(a).join()
        }
        rows := aMapIndexed(this.entries, (i, e) => [beautifyRow(tree[i]) ' ' e[3], readableTime(timeDecode(e[1]))])

        lv := listViewAll(['存档树', '时间'], rows, () => makeGlobalGui(appName))
        lv.OnEvent('DoubleClick', (gc, index) => index == size ? Run(this.target) : 0)
        for i in selections {
            lvSelect(lv, i)
        }

        onEnter(lv) {
            selected := lvGetAllSelected(lv).toArray()
            if selected.Length == 1 {
                index := selected[1]
                if index < size {
                    FileCopy(this.target '\' this.saves[index] '\*', this.src, true)
                    this.changeHead(index)
                    exitGuiWith(this.entries[index][3] ' - 已恢复', 3)
                } else {
                    return '虚拟根节点'
                }
            }
        }
        cmdMap['Enter'] := wrapCmd(lv, onEnter)

        onRButton(lv) {
            selected := lvGetAllSelected(lv).toArray()
            if selected.Length == 2 {
                i := selected[1]
                j := selected[2]
                p := parentMap[i]
                if p == j and p == size {
                    return
                }
                this.changeParent(i, p == j ? size : j)
                this.updateSaves(i, j)
            }
        }
        cmdMap['RButton'] := wrapCmd(lv, onRButton)

        onCtrlUp(lv) {
            index := lv.GetNext()
            if mGet(childrenMap, index, &cr) {
                SendInput('{Up ' index - cr[1] '}')
            }
        }
        cmdMap['CtrlUp'] := wrapCmd(lv, onCtrlUp)

        onCtrlDown(lv) {
            index := lv.GetNext()
            if index < size {
                SendInput('{Down ' parentMap[index] - index '}')
            }
        }
        cmdMap['CtrlDown'] := wrapCmd(lv, onCtrlDown)

        onDel(lv) {
            index := lv.GetNext()
            if index == 0 or index == size {
                return
            }
            parent := parentMap[index]
            if mGet(childrenMap, index, &children) and children.Length > 1 {
                return '存在多个子节点 无法删除'
            }
            curr := this.entries[index]
            if not popupYesNo('删除存档', '是否删除存档：' curr[3]) {
                return
            }
            if IsSet(children) {
                this.changeParent(children[1], parent)
            }
            if curr[1] == this.head and parent < size {
                this.changeHead(parent)
            }
            DirDelete(this.target '\' this.saves[index], true)
            exitGuiWith(curr[3] ' - 已删除', 4)
            this.updateSaves(index)
        }
        cmdMap['Del'] := wrapCmd(lv, onDel)
    }

    updateSaves(selections*) {
        BackupHelper(this.proc, this.src, this.filePattern).showSaves(selections*)
    }

    renameSave(from, id, parent, name) {
        DirMove(this.target '\' from, this.target '\' id '#' parent '#' name, 'R')
    }

    changeHead(index) {
        FileMove(this.target '\' this.head, this.target '\' this.entries[index][1])
    }

    changeParent(index, parent) {
        src := this.entries[index]
        des := this.entries[parent]
        this.renameSave(this.saves[index], src[1], des[1], src[3])
    }
}


; #HotIf isWinActive('AutoHotKey64', appName)
#HotIf isWinActive('backup', appName)
Enter:: cmdMap['Enter'].Call()
^Up:: cmdMap['CtrlUp'].Call()
^Down:: cmdMap['CtrlDown'].Call()
Del:: cmdMap['Del'].Call()
RButton:: cmdMap['RButton'].Call()
F1:: {
    g := makeGui('快捷键列表', g => g.Destroy())
    g.SetFont('s9', 'consolas')
    g.Opt('ToolWindow')
    lines := [
        '游戏或工作界面',
        'Win+F5  : 重新加载',
        'Win+F6  : 新建存档备份',
        'Win+F7  : 打开存档树',
        'Win+F8  : 获取当前程序名',
        'Win+F9  : 获取当前窗口标题',
        '',
        '本应用界面',
        'ESC     : 退出当前窗口',
        'F1      : 快捷键列表',
        '',
        '存档树界面',
        '↑       : 向上（较新存档）',
        '↓       : 向下（较旧存档）',
        'Ctrl+↑  : 向上跳转最新子节点',
        'Ctrl+↓  : 向下跳转父节点',
        'Enter   : 恢复存档',
        'Delete  : 删除存档',
        'RButton : 重设父节点',
    ]
    g.AddText('w190', join(lines, '`n'))
    g.Show()
}
#HotIf

runBackupHelper(action) {
    proc := procName()
    if mGet(procDirMap, proc, &titlePathFiles) {
        title := titlePathFiles[1]
        if not title or isWinTitleMatch(title) {
            action(BackupHelper(proc, titlePathFiles[2], titlePathFiles[3]))
        }
    }
}

#F6:: runBackupHelper(bh => bh.saveFiles())
#F7:: runBackupHelper(bh => bh.showSaves(1))
