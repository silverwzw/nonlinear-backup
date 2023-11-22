#SingleInstance Force
#Include gui.ahk


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

accumulator(dirMap, line) {
    a := StrSplit(line, '=', ' `t', 2)
    if startsWith(line, ';') {
        return
    }
    if a.Length != 2 {
        quit('语法错误：' line)
        stop()
    }
    if not FileExist(a[2]) {
        quit('存档路径不存在：' a[2])
        stop()
    }
    dirMap[a[1]] := a[2]
}

backupIni := 'backup.ini'
if not FileExist(backupIni) {
    quit('同目录下缺失"' backupIni '"文件')
    return
}

dirMap := Seq.readlines(backupIni).reduce(Map(), accumulator)
if dirMap.Count == 0 {
    quit('无存档配置')
    return
}

backupDir := A_WorkingDir


class BackupContext {
    __New(proc, src) {
        this.target := backupDir '\' proc
        this.src := src
        this.saves := scanFilesLatest(this.target, , 'D').map(fileName).toArray()
        this.saveEntries := amap(this.saves, f => StrSplit(f, '#'))
        this.saveEntries.Push(['', '', ''])
        scanFiles(this.target).find(&headFile, f => not fileExt(f))
        this.head := IsSet(headFile) ? fileName(headFile) : ''
    }

    saveFiles(suffix := '*') {
        onEnter(saveName) {
            if isFullMatch(saveName, '\s*') {
                return '不允许空文件夹'
            }
            if hasMatch(saveName, '[\\/:*?"<>|]') {
                return '不能包含非法字符`n\/:*?"<>|'
            }
            srcFiles := scanFiles(this.src).cache()
            srcFiles.map(fileModifiedTime).max(&latestTime)
            if not IsSet(latestTime) {
                return '无可备份文件'
            }
            timestamp := timeEncode(latestTime)
            for i, e in this.saveEntries {
                if e[1] == timestamp {
                    DirMove(this.target '\' this.saves[i], this.target '\' e[1] '#' e[2] '#' saveName, 'R')
                    display(saveName ' - (最新存档)已重命名', , , true)
                    return
                }
            }
            if anyMatch(this.saveEntries, e => e[3] == saveName) {
                return '存档已存在'
            }
            saveFolder := timestamp '#' this.head '#' saveName
            filesBackup(this.target, saveFolder, srcFiles.map(filePath))
            if this.head {
                FileMove(this.target '\' this.head, this.target '\' timestamp)
            } else {
                FileAppend('', this.target '\' timestamp)
            }
            display(saveName ' - 已保存', , , true)
        }
        readInput(() => makeGui(, '微软雅黑'), , '存档名称', onEnter)
    }

    recoverFiles() {
        size := this.saveEntries.Length
        if size <= 1 {
            display('暂无备份')
            return
        }
        nodeIndexMap := Map()
        forEachIndexed(this.saveEntries, (i, e) => nodeIndexMap[e[1]] := i)
        parentMap := range(1, size - 1).toMapWith(i => nodeIndexMap.Get(this.saveEntries[i][2], size))
        childrenMap := range(1, size - 1).groupBy(i => parentMap[i], i => i)
        tree := gen(size, () => repeat(size, ' '))

        foundHead := false
        fillNode(i, j) {
            if not foundHead and this.saveEntries[i][1] == this.head {
                foundHead := true
                tree[i][j] := '╪'
            } else {
                tree[i][j] := '┼'
            }
            if not childrenMap.Has(i) {
                return j
            }
            children := childrenMap[i]
            end := j
            for cOrd, c in children {
                if cOrd == 1 {
                    for k in range(c + 1, i - 1) {
                        tree[k][j] := '│'
                    }
                    end := fillNode(c, j)
                } else {
                    for k in range(j + 1, end) {
                        tree[i][k] := '┴'
                    }
                    tree[i][end + 1] := '└'
                    for k in range(c + 1, i - 1) {
                        tree[k][end + 1] := '│'
                    }
                    end := fillNode(c, end + 1)
                }
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
            return join(reverse(a))

        }
        after := amap(tree, beautifyRow)
        rows := amapIndexed(this.saveEntries, (i, e) => [after[i] ' ' e[3], readableTime(timeDecode(e[1]))])

        onEnter(i) {
            if i < size {
                FileCopy(this.target '\' this.saves[i] '\*', this.src, true)
                FileMove(this.target '\' this.head, this.target '\' this.saveEntries[i][1])
                display(this.saveEntries[i][3] ' - 已恢复')
            } else {
                return '虚拟根节点'
            }
        }
        onDoubleClick(gc, index) {
            if index < size {
                Run('explorer /select,' this.target '\' this.saves[index])
            }
        }
        listViewAll(['存档', '时间'], rows, , , onEnter, onDoubleClick)
    }
}

#LButton:: {
    proc := procName()
    src := dirMap.Get(proc, '')
    if src {
        ac := BackupContext(proc, src)
        ac.saveFiles()
    }
}
#RButton:: {
    proc := procName()
    src := dirMap.Get(proc, '')
    if src {
        ac := BackupContext(proc, src)
        ac.recoverFiles()
    }
}
