/*
 * Copyright (C) 2013  Cable Television Laboratories, Inc.
 *
 * Author: Craig Pratt <craig@ecaspia.com>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CABLE TELEVISION LABORATORIES
 * INC. OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

using GUPnP;

public class Rygel.DTCPCleartextRequest : Rygel.HTTPSeekRequest {
    public static const string DTCP_RANGE_HEADER = "Range.dtcp.com";

    /**
     * The start of the cleartext range in bytes
     */
    public int64 start_byte { get; private set; }

    /**
     * The end of the cleartext range in bytes (inclusive). May be HTTPSeekRequest.UNSPECIFIED
     */
    public int64 end_byte { get; private set; }

    /**
     * The length of the cleartext range in bytes. May be HTTPSeekRequest.UNSPECIFIED
     */
    public int64 range_length { get; private set; }

    /**
     * The length of the cleartext resource in bytes. May be HTTPSeekRequest.UNSPECIFIED
     */
    public int64 total_size { get; private set; }

    public DTCPCleartextRequest (HTTPGet request) throws HTTPSeekRequestError,
                                                         HTTPRequestError {
        base ();

        int64 start, end, total_size;

        // It's only possible to get the cleartext size from a MediaResource
        //  (and only if it is link protected)
        if (request.handler is HTTPMediaResourceHandler) {
            MediaResource resource = (request.handler as HTTPMediaResourceHandler)
                                     .media_resource;
            total_size = resource.cleartext_size;
            if (total_size <= 0) {
                // Even if it's a resource and the content is link-protected, it may have an
                // unknown cleartext size (e.g. if it's live/in-progress content). This doesn't
                // mean the request is invalid, it just means the total size is non-static
                total_size = UNSPECIFIED;
            }
        } else {
            total_size = UNSPECIFIED;
        }

        unowned string range = request.msg.request_headers.get_one (DTCP_RANGE_HEADER);

        if (range == null) {
            throw new HTTPSeekRequestError.INVALID_RANGE ( "%s request header not present",
                                                           DTCP_RANGE_HEADER );
        }

        if (!range.has_prefix ("bytes")) {
            throw new HTTPSeekRequestError.INVALID_RANGE ( "Invalid %s value (missing bytes field): '%s'",
                                                           DTCP_RANGE_HEADER, range );
        }

        var range_tokens = range.substring (6).split ("-", 2); // skip "bytes="
        if (range_tokens[0].length == 0) {
            throw new HTTPSeekRequestError.INVALID_RANGE ( "No range start specified: '%s'",
                                                           range );
        }

        if (!int64.try_parse (range_tokens[0], out start) || (start < 0)) {
            throw new HTTPSeekRequestError.INVALID_RANGE ( "Invalid %s range start: '%s'",
                                                           DTCP_RANGE_HEADER, range );
        }
        // valid range start specified

        // Look for a range end...
        if (range_tokens[1].length == 0) {
            end = UNSPECIFIED;
        } else {
            if (!int64.try_parse (range_tokens[1], out end) || (end <= 0)) {
                throw new HTTPSeekRequestError.INVALID_RANGE ( "Invalid %s range end: '%s'",
                                                               DTCP_RANGE_HEADER, range );
            }
            // valid end range specified
        }

        if ((end != UNSPECIFIED) && (start > end)) {
            throw new HTTPSeekRequestError.INVALID_RANGE ( "Invalid %s range - start > end: '%s'",
                                                           DTCP_RANGE_HEADER, range );
        }

        if ((total_size != UNSPECIFIED) && (start > total_size-1)) {
            throw new HTTPSeekRequestError.OUT_OF_RANGE ( "Invalid %s range - start > length: '%s'",
                                                           DTCP_RANGE_HEADER, range );
        }

        if ((total_size != UNSPECIFIED) && (end > total_size-1)) {
            // It's not clear from the DLNA link protection spec if the range end can be beyond
            //  the total length. We'll assume RFC 2616 14.35.1 semantics. But note that having
            //  an end with an unspecified size will be normal for live/in-progress content
            end = total_size-1;
        }

        this.start_byte = start;
        this.end_byte = end;
        this.range_length = (end == UNSPECIFIED) ? UNSPECIFIED
                                                : end-start+1; // +1, since range is inclusive
        this.total_size = total_size;
    }

    public static bool supported (HTTPGet request) {
        return (request.handler is HTTPMediaResourceHandler)
               && (request.handler as HTTPMediaResourceHandler)
                  .media_resource.is_cleartext_range_support_enabled ();
    }

    public static bool requested (HTTPGet request) {
        return (request.msg.request_headers.get_one (DTCP_RANGE_HEADER) != null);
    }
}
