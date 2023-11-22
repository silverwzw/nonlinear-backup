#Include seq.ahk
#Include utils.ahk


scanFiles(dir, suffix := '*', mode := 'F') {
    fun1(consumer) {
        loop files dir '\*.' suffix, mode {
            consumer([A_LoopFileName, A_LoopFilePath, A_LoopFileTimeModified, A_LoopFileSize, A_LoopFileExt])
        }
    }
    return Seq(fun1)
}

scanFilesLatest(dir, suffix := '*', mode := 'F') {
    return scanFiles(dir, suffix, mode).sortBy(fileModifiedTime, 'R')
}

filesBackup(desDir, subName, filePathSeq) {
    target := desDir '\' subName
    DirCreate(target)
    filePathSeq.consume(f => FileCopy(f, target))
}

fileName(fileArray) {
    return fileArray[1]
}

filePath(fileArray) {
    return fileArray[2]
}

fileModifiedTime(fileArray) {
    return fileArray[3]
}

fileSize(fileArray) {
    return fileArray[4]
}

fileExt(fileArray) {
    return fileArray[5]
}
