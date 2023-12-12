#Include strings.ahk


scanFiles(dir, pattern := '*', mode := 'F') {
    fun(consumer) {
        loop files dir '\' pattern, mode {
            consumer([A_LoopFileName, A_LoopFilePath, A_LoopFileTimeModified, A_LoopFileAttrib, A_LoopFileSize, A_LoopFileExt])
        }
    }
    if pattern == '*.*' and InStr(mode, 'F') {
        return Seq(fun).filter(a => fileIsDir(a) or fileExt(a))
    } else {
        return Seq(fun)
    }
}

scanFilesLatest(dir, pattern := '*', mode := 'F') {
    return scanFiles(dir, pattern, mode).sortBy(fileModifiedTime, 'R')
}

filesBackup(desDir, subName, filePathSeq) {
    target := desDir '\' subName
    DirCreate(target)
    filePathSeq.consume(f => FileCopy(f, target))
}

fileName(a) {
    return a[1]
}

filePath(a) {
    return a[2]
}

fileModifiedTime(a) {
    return a[3]
}

fileAttrib(a) {
    return a[4]
}

fileSize(a) {
    return a[5]
}

fileExt(a) {
    return a[6]
}

fileIsDir(a) {
    return InStr(a[4], 'D')
}
