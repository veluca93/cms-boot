#define BOOST_ASIO_SEPARATE_COMPILATION
#include <stdlib.h>
#include <libtorrent/entry.hpp>
#include <libtorrent/bencode.hpp>
#include <libtorrent/session.hpp>
#include <libtorrent/torrent_handle.hpp>
#include <unistd.h>
#include <stdio.h>
using namespace libtorrent;
using namespace std;

bool _true(torrent_status const&) {return true;}

float nicesz(float sz) {
    while(sz > 1024)
        sz /= 1024;
    return sz;
}

char unitsz(float sz) {
    int cnt = 0;
    while (sz > 1024) {
        sz /= 1024;
        cnt += 1;
    }
    return "BKMGT"[cnt];
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        fputs("usage: ./gettorrent torrent-file [torrent-file [ ... ] ]", stderr);
        return 1;
    }

    session s;
    error_code ec;
    s.listen_on(make_pair(16881, 16889), ec);

    s.start_dht();

    s.add_dht_node(make_pair("10.0.0.1", 6881));

    if (ec) {
        fprintf(stderr, "failed to open listen socket: %s\n", ec.message().c_str());
        return 1;
    }
    for(int i=1; i<argc; i++) {
        add_torrent_params p;
        p.save_path = "/storage/casper/";
        p.ti = new torrent_info(argv[i], ec);
        if (ec) {
            fprintf(stderr, "%s\n", ec.message().c_str());
            return 1;
        }
        s.add_torrent(p, ec);
        if (ec) {
            fprintf(stderr, "%s\n", ec.message().c_str());
            return 1;
        }
    }

    vector<torrent_status>* status = new vector<torrent_status>;

    s.get_torrent_status(status, _true, 0);

    bool isseeding = false;
    while(!isseeding) {
        puts("\033[0;0H");
        usleep(100000);
        s.refresh_torrent_status(status);
        isseeding = true;
        for(vector<torrent_status>::iterator tor=status->begin(); tor!=status->end(); tor++) {
            isseeding &= tor->time_since_download > 5 && tor->total_done == tor->total_wanted;
            printf(
                    "%20.20s: %6.2f%c/%6.2f%c done, %d peer, %d seed\n",
                    tor->handle.name().c_str(),
                    nicesz(tor->total_done), unitsz(tor->total_done),
                    nicesz(tor->total_wanted), unitsz(tor->total_wanted),
                    tor->num_peers,
                    tor->num_seeds
            );
        }
    }
}
