#SingleInstance Force
#Include gui.ahk


cmdMap := (['Enter', 'CtrlUp', 'CtrlDown', 'Del', 'RButton']).toMapWith(name => nothing)
treeListView := unset

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
    configMap := rest
        .map(StrSplit.Bind(, '=', ' `t', 2))
        .filter(a => a.Length == 2)
        .toMap(a => a[1], a => a[2])
    if not configMap.getVal('dir', &dir) {
        quit('缺失存档路径 dir: ' proc)
        stop()
    }
    dir := StrReplace(dir, '{user}', A_UserName)
    if not FileExist(dir) {
        quit('存档路径不存在：' dir)
        stop()
    }
    configMap['dir'] := dir
    return [proc, configMap]
}

procMap := seqReadlines(backupIni)
    .filter(ln => ln and not ln.startsWith(';'))
    .mapSub(ln => ln.surroundedWith('[', ']'), parseConfig)
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

    __New(proc, config) {
        this.proc := proc
        this.target := A_WorkingDir '\' proc
        this.src := config['dir']
        this.title := config.Get('title', '')
        this.pattern := config.Get('pattern', '*')
        this.hotkey := config.Get('hotkey', '')
        this.keywait := config.getNum('keywait', &kw) ? kw : 0
        this.load()
    }

    static clearAuto(config) {
        config.Delete(NonlinearBackup.autoFunc)
        config.Delete(NonlinearBackup.autoText)
    }

    getAppTitle() {
        if procMap.getVal(this.proc, &config) {
            if config.getVal(NonlinearBackup.autoText, &text) {
                return NonlinearBackup.appName ' (' text ')'
            }
        }
        return NonlinearBackup.appName
    }

    loadHead() {
        return scanFiles(this.target).find(&res, f => not fileExt(f)) ? fileName(res) : ''
    }

    load() {
        this.saves := scanFilesLatest(this.target, , 'D').mapOut(fileName)
        this.entries := this.saves.mapOut(f => StrSplit(f, '#', , 3))
        this.nodeIndexMap := this.entries.toIndexMap(e => e[1])
        this.entries.Push(['', '', '[双击打开路径]'])
    }

    getIndex(node, &index) {
        return node and this.nodeIndexMap.getVal(node, &index)
    }

    askRename(saveName, entry) {
        if popupYesNo('重命名存档', '已有存档: ' entry[3] '`n是否重命名') {
            this.renameSave(this.saves[1], entry[1], entry[2], saveName)
            exitGuiWith(saveName ' - 已重命名', 3)
        }
    }

    doSave(saveName, auto, &msg) {
        srcFiles := scanFiles(this.src, this.pattern).toArr()
        if not srcFiles.map(fileModifiedTime).max(&latestTime) {
            msg := '无可备份文件'
            return false
        }
        timestamp := timeEncode(latestTime)
        if this.entries.first(&fst) and timestamp == fst[1] {
            if not auto {
                this.askRename(saveName, fst)
            }
            return false
        }
        head := this.loadHead()
        if timestamp == head {
            if not auto and this.getIndex(head, &headIndex) {
                this.askRename(saveName, this.entries[headIndex])
            }
            return false
        }
        if not auto {
            if this.entries.any(e => e[3] == saveName) {
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
        filesBackup(this.target, timestamp '#' head '#' saveName, srcFiles.map(filePath))
        this.setHead(timestamp)
        if IsSet(treeListView) {
            if gcGetWinId(treeListView, &lvId) and WinExist(lvId) {
                selections := lvGetAllSelected(treeListView).mapOut(i => i + 1)
                this.showSaves(true, selections*)
            } else {
                global treeListView
                treeListView := unset
            }
        }
        return true
    }

    checkAuto(saveName, &msg) {
        if not saveName.startsWith('=') {
            return false
        }
        sub := SubStr(saveName, 2)
        if sub.isFullMatch('[+-]?[0-9]+[hHmMsS]') {
            config := procMap[this.proc]
            len := StrLen(sub)
            num := Integer(SubStr(sub, 1, len - 1))
            if num == 0 {
                if config.getVal(NonlinearBackup.autoFunc, &timer) {
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
            if config.getVal(NonlinearBackup.autoFunc, &old) {
                SetTimer(old, 0)
            }
            f() {
                if this.doSave(String(A_Now), true, &_) {
                    display(this.proc ' - 已自动备份')
                }
                this.load()
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

    saveFiles() {
        g := makeGlobalGui(this.getAppTitle(), '微软雅黑')
        gc := g.AddEdit('r1 w300', '新建备份')
        showGui()

        onEnter(ed) {
            saveName := ed.Value
            if this.checkAuto(saveName, &autoMsg) {
                return IsSet(autoMsg) ? autoMsg : ''
            }
            if saveName.isFullMatch('\s*') {
                return '不允许空文件夹'
            }
            if saveName.hasMatch('[\\/:*?"<>|]') {
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

    showSaves(reload, selections*) {
        if reload {
            this.load()
        }
        size := this.entries.Length
        if size <= 1 {
            display('暂无备份')
            return
        }
        bad := this.entries.filter(e => e.Length < 3).mapOut(e => e[1])
        if bad.Length > 0 {
            if popupYesNo('归档确认', '发现以下未归档备份：`n`n'
                bad.join('`n', f => '- ' f) '`n`n'
                '是否统一归档(Y)或删除(N)`n'
                '归档后将按时间顺序视为连续继承')
            {
                bad.reverse().fold('', (parent, folder) => (
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
            this.showSaves(true, 1)
            display(msg, 3, true)
            return
        }
        rg := range(1, size - 1)
        parentArr := rg.mapOut(i => this.nodeIndexMap.Get(this.entries[i][2], size))
        childrenMap := rg.groupBy(itemGet(parentArr))
        tree := arrRepeatBy(size, () => arrRepeat(size, ' '))

        headIndex := this.nodeIndexMap.Get(this.loadHead(), 0)
        fillNode(i, j) {
            tree[i][j] := headIndex == i ? '╪' : '┼'
            if not childrenMap.getVal(i, &children) {
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
            a := arrRepeat((end << 1) - 1, ' ')
            for i in range(1, end) {
                s := row[i]
                a[(i << 1) - 1] := s
                if s == '└' or s == '┴' or s == '─' {
                    a[(i << 1) - 2] := '─'
                }
            }
            return a.reverse().join()
        }
        rows := this.entries.mapIndexedOut((i, e) => [beautifyRow(tree[i]) ' ' e[3], readableTime(timeDecode(e[1]))])

        global treeListView
        treeListView := lv := listViewAll(['存档树', '时间'], rows, makeGlobalGui.Bind(this.getAppTitle()))
        lv.OnEvent('DoubleClick', (gc, index) => index == size ? Run(this.target) : 0)
        if selections.Length > 0 {
            for i in selections {
                lvSelect(lv, i)
            }
        } else {
            lvSelect(lv, headIndex or 1)
        }

        onEnter(lv) {
            selected := lvGetAllSelected(lv).toArr()
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
            selected := lvGetAllSelected(lv).toArr()
            if selected.Length == 2 {
                i := selected[1]
                j := selected[2]
                p := parentArr[i]
                if p == j and p == size {
                    return
                }
                this.changeParent(i, p == j ? size : j, true)
                this.showSaves(false, i, j)
            }
        }
        cmdMap['RButton'] := wrapCmd(lv, onRButton)

        onCtrlUp(lv) {
            index := lv.GetNext()
            if childrenMap.getVal(index, &cr) {
                SendInput('{Up ' index - cr[1] '}')
            }
        }
        cmdMap['CtrlUp'] := wrapCmd(lv, onCtrlUp)

        onCtrlDown(lv) {
            index := lv.GetNext()
            if index < size {
                SendInput('{Down ' parentArr[index] - index '}')
            }
        }
        cmdMap['CtrlDown'] := wrapCmd(lv, onCtrlDown)

        onDel(lv) {
            selectionSet := lvGetAllSelected(lv).toSet()
            if selectionSet.Has(0) or selectionSet.Has(size) {
                return
            }
            newParentMap := Map()
            for index in selectionSet {
                if childrenMap.getVal(index, &children) {
                    restChildren := children.filterOut(notIn(selectionSet))
                    if restChildren.Length == 0 {
                        continue
                    }
                    if restChildren.Length > 1 {
                        selectionSet.consume(i => lvSelect(lv, i))
                        return this.entries[index][3] ' 存在多个子节点 无法删除'
                    }
                    rest := restChildren[1]
                    newParentMap[rest] := moveUntil(rest, itemGet(parentArr), notIn(selectionSet))
                }
            }
            if not popupYesNo('删除存档', '是否删除存档：`n' selectionSet.join('`n', i => '- ' this.entries[i][3])) {
                return
            }
            if this.getIndex(this.loadHead(), &headIndex) {
                headIndex := moveWhile(headIndex, itemGet(parentArr), isIn(selectionSet))
            }
            for index in selectionSet {
                DirDelete(this.target '\' this.saves[index], true)
            }
            for i, p in newParentMap {
                if p < size {
                    this.changeParent(i, p)
                }
            }
            if IsSet(headIndex) {
                this.changeHead(headIndex)
            }
            exitGuiWith('存档已删除', 4)
            this.showSaves(true, 1)
        }
        cmdMap['Del'] := wrapCmd(lv, onDel)
    }

    renameSave(from, id, parent, name) {
        DirMove(this.target '\' from, this.target '\' id '#' parent '#' name, 'R')
    }

    setHead(timestamp) {
        head := this.loadHead()
        if head {
            if timestamp != head {
                try {
                    FileMove(this.target '\' head, this.target '\' timestamp)
                } catch Error as e {
                    display(head (FileExist(this.target '\' head) ? '存在' : '不存在') ' => ' timestamp)
                }
            }
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
            this.saves[index] := src.join('#')
        }
    }
}


; #HotIf isWinActive('AutoHotKey64', NonlinearBackup.appName '*')
#HotIf isWinActive('backup', NonlinearBackup.appName '*')
Enter:: cmdMap['Enter'].Call()
^Up:: cmdMap['CtrlUp'].Call()
^Down:: cmdMap['CtrlDown'].Call()
Del:: cmdMap['Del'].Call()
RButton:: cmdMap['RButton'].Call()
F1:: {
    g := makeGui('快捷键列表', g => g.Destroy())
    g.SetFont('s9', 'consolas')
    g.Opt('ToolWindow')
    content := "
    (
        游戏或工作界面
        Win+F5  : 重新加载配置
        Win+F6  : 新建存档备份
        Win+F7  : 打开存档树
        Win+F8  : 获取当前程序名
        Win+F9  : 获取当前窗口标题
        
        本应用界面
        ESC     : 退出当前窗口
        F1      : 快捷键列表
        
        存档树界面
        ↑       : 向上（较新存档）
        ↓       : 向下（较旧存档）
        Ctrl+↑  : 向上跳转最新子节点
        Ctrl+↓  : 向下跳转父节点
        Enter   : 载入存档
        Delete  : 删除存档
        RButton : 重设父节点
    )"
    g.AddText('w195', content)
    g.Show()
}
#HotIf

runBackupHelper(action) {
    proc := procName()
    if procMap.getVal(proc, &config) {
        if not config.getVal('title', &title) or not title or isWinTitleMatch(title) {
            action(NonlinearBackup(proc, config))
        }
    }
}

#F6:: runBackupHelper(bh => bh.saveFiles())
#F7:: runBackupHelper(bh => bh.showSaves(false))
