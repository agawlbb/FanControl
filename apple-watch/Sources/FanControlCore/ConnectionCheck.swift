import Foundation

public enum ConnectionCheck {
    public static func failureMessage(_ error: Error) -> String {
        if case ControlError.invalidConfiguration = error { return "Configure a valid remote HTTPS address in Home Assistant." }
        if case ControlError.rejected(let code) = error {
            if code == 401 || code == 403 { return "Pairing rejected by Home Assistant." }
            return "Home Assistant returned HTTP \(code)."
        }
        if let error = error as? URLError {
            switch error.code {
            case .timedOut: return "Connection timed out."
            case .cannotFindHost, .dnsLookupFailed: return "DNS lookup failed."
            case .notConnectedToInternet: return "Watch has no internet connection."
            case .cannotConnectToHost: return "Could not connect to Home Assistant."
            case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
                 .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
                return "Secure connection failed. Check the server certificate."
            default: break
            }
        }
        return "No authenticated response from Home Assistant."
    }
}
