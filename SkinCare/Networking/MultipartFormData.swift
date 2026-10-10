import Foundation

struct MultipartFormData: Sendable {
    let boundary = "Boundary-\(UUID().uuidString)"
    private var parts = Data()

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    mutating func addField(name: String, value: String) {
        appendLine("--\(boundary)")
        appendLine("Content-Disposition: form-data; name=\"\(name)\"")
        appendLine("")
        appendLine(value)
    }

    mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        appendLine("--\(boundary)")
        appendLine("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"")
        appendLine("Content-Type: \(mimeType)")
        appendLine("")
        parts.append(data)
        appendLine("")
    }

    func encoded() -> Data {
        var data = parts
        data.append(Data("--\(boundary)--\r\n".utf8))
        return data
    }

    private mutating func appendLine(_ line: String) {
        parts.append(Data("\(line)\r\n".utf8))
    }
}
