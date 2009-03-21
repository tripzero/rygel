/*
 * Copyright (C) 2009 Nokia Corporation, all rights reserved.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

using Rygel;
using GUPnP;
using Gee;
using Gst;

public abstract class Rygel.TranscodeManager : GLib.Object {
    internal abstract string create_uri_for_item
                                            (MediaItem  item,
                                             string?    transcode_target,
                                             out string protocol);

    internal virtual void add_resources (ArrayList<DIDLLiteResource?> resources,
                                         MediaItem                    item)
                                         throws Error {
        if (item.upnp_class.has_prefix (MediaItem.IMAGE_CLASS)) {
            // No  transcoding for images yet :(
            return;
        } else if (item.upnp_class.has_prefix (MediaItem.MUSIC_CLASS)) {
            L16Transcoder.add_resource (resources, item, this);
            MP3Transcoder.add_resource (resources, item, this);
        } else {
            MP2TSTranscoder.add_resource (resources, item, this);
        }
    }

    internal Element get_transcoding_src (Element src,
                                          string  target)
                                          throws Error {
        if (target == MP3Transcoder.mime_type) {
            return new MP3Transcoder (src, MP3Profile.LAYER3);
        } else if (target == L16Transcoder.mime_type) {
            return new L16Transcoder (src);
        } else if (target == MP2TSTranscoder.mime_type) {
            return new MP2TSTranscoder (src);
        } else {
            throw new HTTPRequestError.NOT_FOUND (
                            "No transcoder available for target format '%s'",
                            target);
        }
    }

    internal DIDLLiteResource create_resource (MediaItem  item,
                                               string     mime_type,
                                               string     dlna_profile)
                                               throws Error {
        string protocol;
        var uri = this.create_uri_for_item (item, mime_type, out protocol);
        DIDLLiteResource res = item.create_res (uri);
        res.mime_type = mime_type;
        res.protocol = protocol;
        res.dlna_profile = dlna_profile;
        res.dlna_conversion = DLNAConversion.TRANSCODED;
        res.dlna_flags = DLNAFlags.STREAMING_TRANSFER_MODE;
        res.dlna_operation = DLNAOperation.NONE;
        res.size = -1;

        return res;
    }
}

