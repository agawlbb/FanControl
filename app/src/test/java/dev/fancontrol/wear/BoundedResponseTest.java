package dev.fancontrol.wear;

import java.io.IOException;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.ResponseBody;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okio.Buffer;
import okio.BufferedSource;
import okio.GzipSink;
import okio.Okio;
import okio.Source;
import okio.Timeout;
import org.junit.Test;
import static org.junit.Assert.*;

public class BoundedResponseTest {
    @Test public void acceptsEmptyExactLimitAndCharset() throws Exception {
        assertEquals("", BoundedResponse.read(ResponseBody.create(new byte[0], null)));
        String exact = "a".repeat(BoundedResponse.MAX_BYTES);
        assertEquals(exact, BoundedResponse.read(ResponseBody.create(exact, null)));
        assertEquals("é", BoundedResponse.read(ResponseBody.create(new byte[]{(byte) 0xe9},
                MediaType.get("text/plain; charset=iso-8859-1"))));
    }

    @Test public void stopsUnendingOrLyingSourceAndClosesIt() throws Exception {
        for (long declared : new long[]{-1, 1, BoundedResponse.MAX_BYTES + 1L}) {
            long[] consumed = {0};
            boolean[] closed = {false};
            BufferedSource source = Okio.buffer(new Source() {
                public long read(Buffer sink, long count) {
                    sink.write(new byte[(int) count]); consumed[0] += count; return count;
                }
                public Timeout timeout() { return Timeout.NONE; }
                public void close() { closed[0] = true; }
            });
            ResponseBody body = new ResponseBody() {
                public MediaType contentType() { return null; }
                public long contentLength() { return declared; }
                public BufferedSource source() { return source; }
            };
            assertTooLarge(body);
            assertTrue(closed[0]);
            // Okio may prefetch one fixed-size segment, but never consumes the unbounded body.
            assertTrue(consumed[0] <= BoundedResponse.MAX_BYTES + 8192L);
            if (declared > BoundedResponse.MAX_BYTES) assertEquals(0, consumed[0]);
        }
    }

    @Test public void rejectsChunkedAndGzipOverflowAfterDecompression() throws Exception {
        String oversized = "a".repeat(BoundedResponse.MAX_BYTES + 1);
        Buffer compressed = new Buffer();
        try (GzipSink gzip = new GzipSink(compressed)) {
            Buffer plain = new Buffer().writeUtf8(oversized);
            gzip.write(plain, plain.size());
        }
        try (MockWebServer server = new MockWebServer()) {
            server.enqueue(new MockResponse().setChunkedBody(oversized, 1024));
            server.enqueue(new MockResponse().setHeader("Content-Encoding", "gzip").setBody(compressed));
            server.start();
            OkHttpClient client = new OkHttpClient();
            for (int i = 0; i < 2; i++) {
                try (var response = client.newCall(new Request.Builder().url(server.url("/")).build()).execute()) {
                    assertTooLarge(response.body());
                }
            }
        }
    }

    @Test public void measuresBytesRatherThanCharacters() throws Exception {
        assertTooLarge(ResponseBody.create("é".repeat(BoundedResponse.MAX_BYTES), MediaType.get("application/json")));
    }

    @Test public void closesBodyWhenReadingFails() throws Exception {
        boolean[] closed = {false};
        BufferedSource source = Okio.buffer(new Source() {
            public long read(Buffer sink, long count) throws IOException { throw new IOException("Cancelled"); }
            public Timeout timeout() { return Timeout.NONE; }
            public void close() { closed[0] = true; }
        });
        ResponseBody body = new ResponseBody() {
            public MediaType contentType() { return null; }
            public long contentLength() { return -1; }
            public BufferedSource source() { return source; }
        };
        try { BoundedResponse.read(body); fail(); }
        catch (IOException expected) { assertEquals("Cancelled", expected.getMessage()); }
        assertTrue(closed[0]);
    }

    private static void assertTooLarge(ResponseBody body) throws Exception {
        try { BoundedResponse.read(body); fail("Oversized response accepted"); }
        catch (IOException expected) { assertEquals("Response too large", expected.getMessage()); }
    }
}
