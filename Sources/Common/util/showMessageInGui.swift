import Foundation

// todo refactor. showMessageInGui in common code looks weird
public func showMessageInGui(filenameIfConsoleApp: String?, title: String, message: String) {
    let titleAndMessage = "##### \(title) #####\n\n" + message
    if isCli {
        print(titleAndMessage)
    } else if let filenameIfConsoleApp {
        let cachesDir = URL(filePath: "/tmp/bobko.aerospace/")
        Result { try FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true) }.getOrDie()
        let file = cachesDir.appending(component: filenameIfConsoleApp)
        Result { try (titleAndMessage + "\n").write(to: file, atomically: true, encoding: .utf8) }.getOrDie()

        file.absoluteURL.open(with: URL(filePath: "/System/Applications/Utilities/Console.app"))
    } else {
        let args = [
            "-e",
            """
            display dialog "\(message.replacing("\"", with: "\\\""))" with title "\(title)"
            """,
        ]
        Result { try? Process.run(URL(filePath: "/usr/bin/osascript"), arguments: args) }.getOrDie()
        // === Alternatives ===
        // let myPopup = NSAlert()
        // myPopup.messageText = message
        // myPopup.alertStyle = NSAlert.Style.informational
        // myPopup.addButton(withTitle: "OK")
        // myPopup.runModal()

        // let alert = UIAlertController(title: "Alert", message: message, preferredStyle: UIAlertControllerStyle.alert)
        // alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.default, handler: nil))
        // self.present(alert, animated: true, completion: nil)

        // file.absoluteURL.open(with: URL(filePath: "/System/Applications/Utilities/Console.app"))
        // file.absoluteURL.open(with: URL(filePath: "/System/Applications/TextEdit.app"))
    }
}
