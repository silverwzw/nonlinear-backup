#SingleInstance Force
#Include gui.ahk


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

parseConfig(head, rest) {
    proc := SubStr(head, 2, StrLen(head) - 2)
    if not rest {
        quit('未找到配置：' proc)
        stop()
    }
    configMap := seqOf(rest)
        .map(ln => StrSplit(ln, '=', ' `t', 2))
        .filter(a => a.Length == 2)
        .toMap(a => a[1], a => a[2])
    if not mGet(configMap, 'dir', &dir) {
        quit('缺失存档路径 dir: ' proc)
        stop()
    } else if not FileExist(dir) {
        quit('存档路径不存在：' dir)
        stop()
    }
    return [proc, configMap]
}

procMap := seqReadlines(backupIni)
    .filter(ln => ln and not startsWith(ln, ';'))
    .mapSub(ln => surroundedWith(ln, '[', ']'), parseConfig)
    .toMap(a => a[1], a => a[2])


if procMap.Count == 0 {
    quit('无存档配置')
    return
}

exitGuiWith(msg, sec) {
    exitGui(, g => display(msg, sec, true))
    for k in cmdMap {
        cmdMap[k] := nothing
    }
}

class NonlinearBackup {
    static appName := '非线性备份'
    static autoFunc := 'autoFunc'
    static autoText := 'autoText'
    static backupDir := A_WorkingDir

    __New(proc, config) {
        this.proc := proc
        this.target := NonlinearBackup.backupDir '\' proc
        this.src := config['dir']
        this.title := config.Get('title', '')
        this.pattern := config.Get('pattern', '*')
        this.hotkey := config.Get('hotkey', '')
        this.keywait := nGetMaybe(config, 'keywait').orElse(0)
        this.update()
    }

    static clearAuto(config) {
        config.Delete(NonlinearBackup.autoFunc)
        config.Delete(NonlinearBackup.autoText)
    }

    getAppTitle() {
        if mGet(procMap, this.proc, &config) {
            if mGet(config, NonlinearBackup.autoText, &text) {
                return NonlinearBackup.appName ' (' text ')'
            }
        }
        return NonlinearBackup.appName
    }

    update() {
        this.saves := scanFilesLatest(this.target, , 'D').map(fileName).toArray()
        this.entries := aMap(this.saves, f => StrSplit(f, '#'))
        this.entries.Push(['', '', '[双击打开路径]'])
        this.head := scanFiles(this.target).findMaybe(f => not fileExt(f)).mapOr(fileName, '')
    }

    doSave(saveName, auto, &msg) {
        srcFiles := scanFiles(this.src, this.pattern).cache()
        if not srcFiles.map(fileModifiedTime).max(&latestTime) {
            msg := '无可备份文件'
            return false
        }
        timestamp := timeEncode(latestTime)
        first := this.entries[1]
        if first[1] == timestamp {
            if not auto and popupYesNo('重命名存档', '已有最新存档: ' first[3] '`n是否重命名') {
                this.renameSave(this.saves[1], first[1], first[2], saveName)
                exitGuiWith(saveName ' - 已重命名', 3)
            }
            ; msg := '已是最新'
            return false
        }
        if not auto {
            if anyMatch(this.entries, e => e[3] == saveName) {
                msg := '存档已存在'
                return false
            }
        }
        if this.hotkey {
            if isWinActive(this.proc, this.title) {
                SendInput(this.hotkey)
                Sleep((this.keywait or 1) * 1000)
            }
        }
        folder := timestamp '#' this.head '#' saveName
        filesBackup(this.target, folder, srcFiles.map(filePath))
        this.setHead(timestamp)
        return true
    }

    checkAuto(saveName, &msg) {
        if startsWith(saveName, 'auto=') {
            sub := SubStr(saveName, 6)
            if isFullMatch(sub, '[+-]?[0-9]+[hHmMsS]') {
                config := procMap[this.proc]
                len := StrLen(sub)
                num := Integer(SubStr(sub, 1, len - 1))
                if num == 0 {
                    if mGet(config, NonlinearBackup.autoFunc, &timer) {
                        SetTimer(timer, 0)
                        NonlinearBackup.clearAuto(config)
                        exitGuiWith('关闭自动备份', 3)
                        return true
                    } else {
                        msg := '自动备份未开启'
                        return true
                    }
                }
                unit := SubStr(sub, len)
                millis := num * 1000
                if unit = 'm' {
                    millis *= 60
                } else if unit = 'h' {
                    millis *= 3600
                }
                config := procMap[this.proc]
                if mGet(config, NonlinearBackup.autoFunc, &old) {
                    SetTimer(old, 0)
                }
                f() {
                    if this.doSave(String(A_Now), true, &_) {
                        display(this.proc ' - 已自动备份')
                    }
                    this.update()
                    if num < 0 {
                        NonlinearBackup.clearAuto(config)
                    }
                }
                config[NonlinearBackup.autoFunc] := f
                config[NonlinearBackup.autoText] := sub
                SetTimer(f, millis)
                exitGuiWith((num > 0 ? '开启自动备份：' : '预约备份：') sub, 3)
                return true
            } else {
                msg := '自动备份语法错误'
                return true
            }
        }
        return false
    }

    saveFiles() {
        g := makeGlobalGui(this.getAppTitle(), '微软雅黑')
        gc := g.AddEdit('r1 w300', '新建备份')
        showGui()

        onEnter(ed) {
            saveName := ed.Value
            if this.checkAuto(saveName, &autoMsg) {
                return IsSet(autoMsg) ? autoMsg : ''
            }
            if isFullMatch(saveName, '\s*') {
                return '不允许空文件夹'
            }
            if hasMatch(saveName, '[\\/:*?"<>|]') {
                return '不能包含非法字符`n\/:*?"<>|'
            }
            if not this.doSave(saveName, false, &saveMsg) {
                if IsSet(saveMsg) and saveMsg {
                    return saveMsg
                }
            } else {
                exitGuiWith(saveName ' - 已保存', 3)
            }
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
            this.update()
            this.showSaves()
            display(msg, 3, true)
            return
        }
        rg := range(1, size - 1)
        nodeIndexMap := rg.toMapBy(i => this.entries[i][1])
        parentMap := rg.toMapWith(i => nodeIndexMap.Get(this.entries[i][2], size))
        childrenMap := rg.groupBy(i => parentMap[i], i => i)
        tree := repeatBy(size, () => repeat(size, ' '))

        foundHead := false
        fillNode(i, j) {
            if not foundHead and this.entries[i][1] == this.head {
                foundHead := true
                tree[i][j] := '╪'
            } else {
                tree[i][j] := '┼'
            }
            if not mGet(childrenMap, i, &children) {
                return j
            }
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
            a := repeat((end << 1) - 1, ' ')
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

        lv := listViewAll(['存档树', '时间'], rows, () => makeGlobalGui(this.getAppTitle()))
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
                    exitGuiWith(this.entries[index][3] ' - 已载入', 3)
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
                this.changeParent(i, p == j ? size : j, true)
                this.showSaves(i, j)
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
            this.update()
            this.showSaves(index)
        }
        cmdMap['Del'] := wrapCmd(lv, onDel)
    }

    renameSave(from, id, parent, name) {
        DirMove(this.target '\' from, this.target '\' id '#' parent '#' name, 'R')
    }

    setHead(timestamp) {
        if this.head {
            FileMove(this.target '\' this.head, this.target '\' timestamp)
        } else {
            FileAppend('', this.target '\' timestamp)
        }
    }

    changeHead(index) {
        this.setHead(this.entries[index][1])
    }

    changeParent(index, parent, inplace := false) {
        src := this.entries[index]
        des := this.entries[parent]
        this.renameSave(this.saves[index], src[1], des[1], src[3])
        if inplace {
            src[2] := des[1]
            this.saves[index] := join(src, '#')
        }
    }
}


#HotIf isWinActive('AutoHotKey64', NonlinearBackup.appName '*')
; #HotIf isWinActive('backup', BackupHelper.appName '*')
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
        'Win+F5  : 重新加载配置',
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
        'Enter   : 载入存档',
        'Delete  : 删除存档',
        'RButton : 重设父节点',
    ]
    g.AddText('w190', join(lines, '`n'))
    g.Show()
}
#HotIf

runBackupHelper(action) {
    proc := procName()
    if mGet(procMap, proc, &config) {
        if mGet(config, 'title', &title) {
            if not title or isWinTitleMatch(title) {
                action(NonlinearBackup(proc, config))
            }
        }
    }
}

#F6:: runBackupHelper(bh => bh.saveFiles())
#F7:: runBackupHelper(bh => bh.showSaves(1))
