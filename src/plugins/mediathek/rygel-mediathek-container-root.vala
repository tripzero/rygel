/*
 * Copyright (C) 2009 Jens Georg
 *
 * Author: Jens Georg <mail@jensge.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

using Gee;
using Rygel;
using Soup;
using GConf;

public class ZdfMediathek.ZdfRootContainer : MediaContainer {
    private ArrayList<RssContainer> items;
    internal SessionAsync session;
    private GConf.Client gconf;

    public override void get_children(uint offset, uint max_count, 
        Cancellable? cancellable, AsyncReadyCallback callback)
    {
        uint stop = offset + max_count;
        stop = stop.clamp(0, this.child_count);
        var children = this.items.slice ((int)offset, (int)stop);

        var res = new Rygel.SimpleAsyncResult<Gee.List<MediaObject>> (this,
        callback);
        res.data = children;
        res.complete_in_idle();
    }

    public override Gee.List<MediaObject>? get_children_finish (AsyncResult
    res)
                                                         throws GLib.Error {
        var simple_res = (Rygel.SimpleAsyncResult<Gee.List<MediaObject>>) res;

        return simple_res.data;
    }
    public override void find_object (string id, Cancellable? cancellable,
    AsyncReadyCallback callback) {
        var res = new Rygel.SimpleAsyncResult<string> (this,
            callback);

        res.data = id;
        res.complete_in_idle();
    }

    public override MediaObject? find_object_finish (AsyncResult res) throws
    GLib.Error {
        MediaObject item = null;
        var id = ((Rygel.SimpleAsyncResult<string>)res).data;

        foreach (RssContainer tmp in this.items) {
            if (id == tmp.id) {
                item = tmp;
                break;
            }
        }

        if (item == null) {
            foreach (RssContainer container in this.items) {
                item = container.find_object_sync(id);
                if (item != null) {
                    break;
                }
            }
        }

        return item;
    }

    private bool on_schedule_update() {
        message("Scheduling update for all feeds....");
        foreach (RssContainer container in this.items) {
            container.update();
        }

        return true;
    }

    public ZdfRootContainer() {
        base.root("ZDF Mediathek", 0);
        this.session = new Soup.SessionAsync ();
        this.items = new ArrayList<RssContainer>();

        this.gconf = GConf.Client.get_default();
        unowned SList<int> feeds = null;

        // get subscribed feeds
        try {
            // TODO get gconf prefix from Rygel
            feeds = gconf.get_list("/apps/rygel/ZDFMediathek/rss",
                                GConf.ValueType.INT);

        } catch (GLib.Error error) {
            message("Error on getting configuration: %s", error.message);
        }

        if (feeds == null) {
            message("Could not get RSS items from GConf, using defaults");
            feeds.append(508);
        }

        foreach (int id in feeds) {
            this.items.add(new RssContainer(this, id));
        }

        this.child_count = this.items.size;
        GLib.Timeout.add_seconds(1800, on_schedule_update);
    }
}
