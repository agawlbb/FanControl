package dev.fancontrol.wear;

import java.io.IOException;
import okhttp3.ResponseBody;
import okio.Buffer;

/** Bounds decoded response bytes, including chunked and transparently decompressed bodies. */
final class BoundedResponse {
    static final int MAX_BYTES = 24 * 1024;

    private BoundedResponse() { }

    static String read(ResponseBody body) throws IOException {
        if (body == null) throw new IOException("Empty response");
        try (body) {
            if (body.contentLength() > MAX_BYTES) throw new IOException("Response too large");
            Buffer buffer = new Buffer();
            // Read at most one byte beyond the limit to distinguish exact-size bodies from overflow.
            while (body.source().read(buffer, Math.min(8192L, MAX_BYTES + 1L - buffer.size())) != -1) {
                if (buffer.size() > MAX_BYTES) throw new IOException("Response too large");
            }
            // Preserve OkHttp charset and BOM handling only after the byte bound is established.
            try (ResponseBody bounded = ResponseBody.create(buffer.readByteArray(), body.contentType())) {
                return bounded.string();
            }
        }
    }
}
