#!/usr/bin/env python3
"""Music Metadata Manager — Read, write, batch-edit audio tags, rename & organize files."""

import argparse
import csv
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import mutagen
    from mutagen.easyid3 import EasyID3
    from mutagen.flac import FLAC
    from mutagen.oggvorbis import OggVorbis
    from mutagen.mp4 import MP4
    from mutagen.asf import ASF
    from mutagen.id3 import ID3NoHeaderError
except ImportError:
    print("ERROR: mutagen not installed. Run: pip3 install mutagen")
    sys.exit(1)

AUDIO_EXTENSIONS = {'.mp3', '.flac', '.ogg', '.m4a', '.mp4', '.aac', '.wma', '.wav', '.opus'}

TAG_MAP_MP4 = {
    'title': '\xa9nam', 'artist': '\xa9ART', 'album': '\xa9alb',
    'year': '\xa9day', 'genre': '\xa9gen', 'track': 'trkn',
}

def is_audio(path):
    return Path(path).suffix.lower() in AUDIO_EXTENSIONS

def find_audio(directory, recursive=False):
    d = Path(directory)
    pattern = '**/*' if recursive else '*'
    return sorted(p for p in d.glob(pattern) if p.is_file() and is_audio(p))

def get_duration_ffprobe(path):
    try:
        r = subprocess.run(
            ['ffprobe', '-v', 'quiet', '-print_format', 'json', '-show_format', str(path)],
            capture_output=True, text=True, timeout=10
        )
        if r.returncode == 0:
            info = json.loads(r.stdout)
            dur = float(info.get('format', {}).get('duration', 0))
            br = int(info.get('format', {}).get('bit_rate', 0)) // 1000
            return dur, br
    except Exception:
        pass
    return 0, 0

def format_duration(seconds):
    m, s = divmod(int(seconds), 60)
    return f"{m}:{s:02d}"

def read_tags(path):
    """Read tags from an audio file. Returns dict."""
    p = Path(path)
    ext = p.suffix.lower()
    tags = {'file': p.name, 'path': str(p)}

    try:
        if ext == '.mp3':
            try:
                audio = EasyID3(str(p))
            except ID3NoHeaderError:
                audio = {}
            tags['title'] = ', '.join(audio.get('title', ['']))
            tags['artist'] = ', '.join(audio.get('artist', ['']))
            tags['album'] = ', '.join(audio.get('album', ['']))
            tags['year'] = ', '.join(audio.get('date', ['']))
            tags['track'] = ', '.join(audio.get('tracknumber', ['']))
            tags['genre'] = ', '.join(audio.get('genre', ['']))
            m = mutagen.File(str(p))
            if m and m.info:
                tags['duration'] = m.info.length
                tags['bitrate'] = getattr(m.info, 'bitrate', 0) // 1000
            tags['format'] = 'MP3'

        elif ext == '.flac':
            audio = FLAC(str(p))
            tags['title'] = ', '.join(audio.get('title', ['']))
            tags['artist'] = ', '.join(audio.get('artist', ['']))
            tags['album'] = ', '.join(audio.get('album', ['']))
            tags['year'] = ', '.join(audio.get('date', ['']))
            tags['track'] = ', '.join(audio.get('tracknumber', ['']))
            tags['genre'] = ', '.join(audio.get('genre', ['']))
            tags['duration'] = audio.info.length if audio.info else 0
            tags['bitrate'] = (audio.info.bitrate // 1000) if audio.info and hasattr(audio.info, 'bitrate') else 0
            tags['format'] = 'FLAC'

        elif ext in ('.ogg', '.opus'):
            audio = OggVorbis(str(p)) if ext == '.ogg' else mutagen.File(str(p))
            if audio:
                tags['title'] = ', '.join(audio.get('title', ['']))
                tags['artist'] = ', '.join(audio.get('artist', ['']))
                tags['album'] = ', '.join(audio.get('album', ['']))
                tags['year'] = ', '.join(audio.get('date', ['']))
                tags['track'] = ', '.join(audio.get('tracknumber', ['']))
                tags['genre'] = ', '.join(audio.get('genre', ['']))
                tags['duration'] = audio.info.length if audio.info else 0
                tags['bitrate'] = 0
            tags['format'] = ext[1:].upper()

        elif ext in ('.m4a', '.mp4', '.aac'):
            audio = MP4(str(p))
            tags['title'] = ', '.join(audio.get('\xa9nam', ['']))
            tags['artist'] = ', '.join(audio.get('\xa9ART', ['']))
            tags['album'] = ', '.join(audio.get('\xa9alb', ['']))
            tags['year'] = ', '.join(audio.get('\xa9day', ['']))
            tags['genre'] = ', '.join(audio.get('\xa9gen', ['']))
            trkn = audio.get('trkn', [(0, 0)])
            tags['track'] = str(trkn[0][0]) if isinstance(trkn[0], tuple) else str(trkn[0])
            tags['duration'] = audio.info.length if audio.info else 0
            tags['bitrate'] = (audio.info.bitrate // 1000) if audio.info else 0
            tags['format'] = 'M4A'

        elif ext == '.wma':
            audio = ASF(str(p))
            tags['title'] = str(audio.get('Title', [''])[0]) if audio.get('Title') else ''
            tags['artist'] = str(audio.get('Author', [''])[0]) if audio.get('Author') else ''
            tags['album'] = str(audio.get('WM/AlbumTitle', [''])[0]) if audio.get('WM/AlbumTitle') else ''
            tags['year'] = str(audio.get('WM/Year', [''])[0]) if audio.get('WM/Year') else ''
            tags['genre'] = str(audio.get('WM/Genre', [''])[0]) if audio.get('WM/Genre') else ''
            tags['track'] = str(audio.get('WM/TrackNumber', [''])[0]) if audio.get('WM/TrackNumber') else ''
            tags['duration'] = audio.info.length if audio.info else 0
            tags['bitrate'] = 0
            tags['format'] = 'WMA'

        elif ext == '.wav':
            dur, br = get_duration_ffprobe(p)
            tags['duration'] = dur
            tags['bitrate'] = br
            tags['format'] = 'WAV'
            tags['title'] = tags['artist'] = tags['album'] = ''
            tags['year'] = tags['track'] = tags['genre'] = ''

        else:
            m = mutagen.File(str(p))
            if m:
                tags['duration'] = m.info.length if m.info else 0
                tags['bitrate'] = getattr(m.info, 'bitrate', 0) // 1000 if m.info else 0
            tags['format'] = ext[1:].upper()

    except Exception as e:
        tags['error'] = str(e)

    return tags

def write_tags(path, title=None, artist=None, album=None, year=None, track=None, genre=None):
    """Write tags to an audio file."""
    p = Path(path)
    ext = p.suffix.lower()

    if ext == '.mp3':
        try:
            audio = EasyID3(str(p))
        except ID3NoHeaderError:
            from mutagen.id3 import ID3
            audio = EasyID3()
            audio.filename = str(p)
            audio.save()
            audio = EasyID3(str(p))
        if title: audio['title'] = title
        if artist: audio['artist'] = artist
        if album: audio['album'] = album
        if year: audio['date'] = str(year)
        if track: audio['tracknumber'] = str(track)
        if genre: audio['genre'] = genre
        audio.save()

    elif ext == '.flac':
        audio = FLAC(str(p))
        if title: audio['title'] = title
        if artist: audio['artist'] = artist
        if album: audio['album'] = album
        if year: audio['date'] = str(year)
        if track: audio['tracknumber'] = str(track)
        if genre: audio['genre'] = genre
        audio.save()

    elif ext in ('.ogg', '.opus'):
        audio = OggVorbis(str(p)) if ext == '.ogg' else mutagen.File(str(p))
        if audio:
            if title: audio['title'] = [title]
            if artist: audio['artist'] = [artist]
            if album: audio['album'] = [album]
            if year: audio['date'] = [str(year)]
            if track: audio['tracknumber'] = [str(track)]
            if genre: audio['genre'] = [genre]
            audio.save()

    elif ext in ('.m4a', '.mp4', '.aac'):
        audio = MP4(str(p))
        if title: audio['\xa9nam'] = [title]
        if artist: audio['\xa9ART'] = [artist]
        if album: audio['\xa9alb'] = [album]
        if year: audio['\xa9day'] = [str(year)]
        if genre: audio['\xa9gen'] = [genre]
        if track: audio['trkn'] = [(int(track), 0)]
        audio.save()

    elif ext == '.wav':
        print(f"⚠️  WAV does not support tag writing: {p.name}")
        return False

    else:
        print(f"⚠️  Unsupported format for writing: {ext}")
        return False

    return True

def safe_filename(name):
    """Sanitize filename."""
    name = re.sub(r'[<>:"/\\|?*]', '_', name)
    name = name.strip('. ')
    return name or 'Unknown'

def cmd_read(args):
    path = Path(args.path)
    if path.is_file():
        files = [path]
    elif path.is_dir():
        files = find_audio(path, args.recursive)
    else:
        print(f"ERROR: {path} not found")
        return 1

    for f in files:
        t = read_tags(f)
        if 'error' in t:
            print(f"❌ {t['file']}: {t['error']}")
            continue
        dur = format_duration(t.get('duration', 0))
        print(f"\n📄 {t['file']}")
        print(f"  Title:    {t.get('title', '')}")
        print(f"  Artist:   {t.get('artist', '')}")
        print(f"  Album:    {t.get('album', '')}")
        print(f"  Year:     {t.get('year', '')}")
        print(f"  Track:    {t.get('track', '')}")
        print(f"  Genre:    {t.get('genre', '')}")
        print(f"  Duration: {dur}")
        print(f"  Bitrate:  {t.get('bitrate', 0)} kbps")
        print(f"  Format:   {t.get('format', '?')}")
    return 0

def cmd_scan(args):
    files = find_audio(args.path, args.recursive)
    if not files:
        print("No audio files found.")
        return 1

    print(f"{'File':<40} {'Title':<25} {'Artist':<20} {'Album':<20} {'Year':<6} {'Genre':<15} {'Duration':<8}")
    print("-" * 140)
    for f in files:
        t = read_tags(f)
        dur = format_duration(t.get('duration', 0))
        print(f"{t['file'][:39]:<40} {t.get('title','')[:24]:<25} {t.get('artist','')[:19]:<20} {t.get('album','')[:19]:<20} {t.get('year','')[:5]:<6} {t.get('genre','')[:14]:<15} {dur:<8}")
    print(f"\nTotal: {len(files)} files")
    return 0

def cmd_write(args):
    if not Path(args.path).is_file():
        print(f"ERROR: {args.path} is not a file")
        return 1
    ok = write_tags(args.path, args.title, args.artist, args.album, args.year, args.track, args.genre)
    if ok:
        print(f"✅ Tags written to {Path(args.path).name}")
    return 0 if ok else 1

def cmd_batch_tag(args):
    files = find_audio(args.path, getattr(args, 'recursive', False))
    if not files:
        print("No audio files found.")
        return 1

    dry = args.dry_run or os.environ.get('MUSIC_META_DRY_RUN') == '1'
    count = 0
    for f in files:
        if dry:
            print(f"[DRY RUN] Would tag: {f.name}")
        else:
            ok = write_tags(f, args.title, args.artist, args.album, args.year, args.track, args.genre)
            if ok:
                count += 1
                print(f"✅ {f.name}")
            else:
                print(f"❌ {f.name}")

    print(f"\n{'Would tag' if dry else 'Tagged'}: {count if not dry else len(files)}/{len(files)} files")
    return 0

def cmd_rename(args):
    files = find_audio(args.path, getattr(args, 'recursive', False))
    if not files:
        print("No audio files found.")
        return 1

    pattern = args.pattern
    dry = args.dry_run or os.environ.get('MUSIC_META_DRY_RUN') == '1'
    count = 0

    for f in files:
        t = read_tags(f)
        try:
            track_num = int(re.search(r'\d+', t.get('track', '0')).group()) if t.get('track') else 0
        except:
            track_num = 0

        replacements = {
            'title': t.get('title', '') or 'Unknown',
            'artist': t.get('artist', '') or 'Unknown',
            'album': t.get('album', '') or 'Unknown',
            'year': t.get('year', '') or '0000',
            'track': track_num,
            'genre': t.get('genre', '') or 'Unknown',
        }

        try:
            new_name = pattern.format(**replacements)
        except (KeyError, ValueError) as e:
            print(f"⚠️  Pattern error for {f.name}: {e}")
            continue

        if args.safe_rename:
            new_name = safe_filename(new_name)
        new_name = safe_filename(new_name) + f.suffix
        new_path = f.parent / new_name

        if new_path == f:
            continue

        if dry:
            print(f"[DRY RUN] {f.name} → {new_name}")
        else:
            if new_path.exists():
                print(f"⚠️  Skipping {f.name}: {new_name} already exists")
                continue
            f.rename(new_path)
            print(f"✅ {f.name} → {new_name}")
            count += 1

    print(f"\n{'Would rename' if dry else 'Renamed'}: {count if not dry else len(files)} files")
    return 0

def cmd_organize(args):
    files = find_audio(args.path, recursive=True)
    if not files:
        print("No audio files found.")
        return 1

    dest = Path(args.dest or os.environ.get('MUSIC_META_OUTPUT', './organized'))
    structure = args.structure
    dry = args.dry_run or os.environ.get('MUSIC_META_DRY_RUN') == '1'
    count = 0

    for f in files:
        t = read_tags(f)
        try:
            track_num = int(re.search(r'\d+', t.get('track', '0')).group()) if t.get('track') else 0
        except:
            track_num = 0

        replacements = {
            'title': safe_filename(t.get('title', '') or 'Unknown'),
            'artist': safe_filename(t.get('artist', '') or 'Unknown Artist'),
            'album': safe_filename(t.get('album', '') or 'Unknown Album'),
            'year': t.get('year', '') or '0000',
            'track': track_num,
            'genre': safe_filename(t.get('genre', '') or 'Unknown'),
        }

        try:
            rel_dir = structure.format(**replacements)
        except (KeyError, ValueError):
            rel_dir = 'Unsorted'

        fname = f"{track_num:02d} - {safe_filename(t.get('title', '') or f.stem)}{f.suffix}" if track_num else f.name
        target = dest / rel_dir / fname

        if dry:
            print(f"[DRY RUN] {f} → {target}")
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                print(f"⚠️  Skipping {f.name}: target exists")
                continue
            shutil.copy2(str(f), str(target))
            print(f"✅ → {target}")
            count += 1

    print(f"\n{'Would organize' if dry else 'Organized'}: {count if not dry else len(files)} files into {dest}")
    return 0

def cmd_audit(args):
    files = find_audio(args.path, args.recursive)
    required = set(args.require.split(',')) if args.require else {'title', 'artist', 'album'}
    missing_files = []

    for f in files:
        t = read_tags(f)
        missing = [field for field in required if not t.get(field, '').strip()]
        if missing:
            missing_files.append((f.name, missing))

    if missing_files:
        print(f"⚠️  {len(missing_files)} files with missing tags:\n")
        for fname, missing in missing_files:
            print(f"  {fname} — missing: {', '.join(missing)}")
    else:
        print(f"✅ All {len(files)} files have complete tags ({', '.join(required)})")
    return 0

def cmd_strip(args):
    path = Path(args.path)
    files = [path] if path.is_file() else find_audio(path, args.recursive)
    dry = args.dry_run or os.environ.get('MUSIC_META_DRY_RUN') == '1'

    for f in files:
        if dry:
            print(f"[DRY RUN] Would strip tags from: {f.name}")
        else:
            try:
                audio = mutagen.File(str(f))
                if audio:
                    audio.delete()
                    audio.save()
                    print(f"✅ Stripped: {f.name}")
            except Exception as e:
                print(f"❌ {f.name}: {e}")
    return 0

def cmd_export(args):
    files = find_audio(args.path, args.recursive)
    data = []
    for f in files:
        t = read_tags(f)
        t['duration'] = t.get('duration', 0)
        data.append(t)
    print(json.dumps(data, indent=2, default=str))
    return 0

def cmd_import_tags(args):
    with open(args.json_file, 'r') as f:
        data = json.load(f)

    count = 0
    for entry in data:
        p = entry.get('path')
        if not p or not Path(p).exists():
            print(f"⚠️  File not found: {p}")
            continue
        ok = write_tags(p, entry.get('title'), entry.get('artist'), entry.get('album'),
                       entry.get('year'), entry.get('track'), entry.get('genre'))
        if ok:
            count += 1
    print(f"✅ Imported tags for {count} files")
    return 0

def cmd_csv_import(args):
    with open(args.csv_file, 'r', newline='') as f:
        reader = csv.DictReader(f)
        count = 0
        for row in reader:
            p = row.get('filename') or row.get('file') or row.get('path')
            if not p or not Path(p).exists():
                print(f"⚠️  File not found: {p}")
                continue
            ok = write_tags(p, row.get('title'), row.get('artist'), row.get('album'),
                           row.get('year'), row.get('track'), row.get('genre'))
            if ok:
                count += 1
    print(f"✅ Imported tags for {count} files from CSV")
    return 0

def main():
    parser = argparse.ArgumentParser(description='Music Metadata Manager')
    sub = parser.add_subparsers(dest='command')

    # read
    p_read = sub.add_parser('read', help='Read tags from file(s)')
    p_read.add_argument('path', help='File or directory')
    p_read.add_argument('-r', '--recursive', action='store_true')

    # scan
    p_scan = sub.add_parser('scan', help='Scan directory, show tag summary')
    p_scan.add_argument('path', help='Directory to scan')
    p_scan.add_argument('-r', '--recursive', action='store_true')

    # write
    p_write = sub.add_parser('write', help='Write tags to a file')
    p_write.add_argument('path', help='Audio file')
    p_write.add_argument('--title')
    p_write.add_argument('--artist')
    p_write.add_argument('--album')
    p_write.add_argument('--year')
    p_write.add_argument('--track')
    p_write.add_argument('--genre')

    # batch-tag
    p_batch = sub.add_parser('batch-tag', help='Tag all files in a directory')
    p_batch.add_argument('path', help='Directory')
    p_batch.add_argument('--title')
    p_batch.add_argument('--artist')
    p_batch.add_argument('--album')
    p_batch.add_argument('--year')
    p_batch.add_argument('--track')
    p_batch.add_argument('--genre')
    p_batch.add_argument('-r', '--recursive', action='store_true')
    p_batch.add_argument('--dry-run', action='store_true')

    # rename
    p_rename = sub.add_parser('rename', help='Rename files based on tags')
    p_rename.add_argument('path', help='Directory')
    p_rename.add_argument('--pattern', default='{track:02d} - {title}')
    p_rename.add_argument('-r', '--recursive', action='store_true')
    p_rename.add_argument('--dry-run', action='store_true')
    p_rename.add_argument('--safe-rename', action='store_true')

    # organize
    p_org = sub.add_parser('organize', help='Organize files into folders by tags')
    p_org.add_argument('path', help='Source directory')
    p_org.add_argument('--dest', help='Destination directory')
    p_org.add_argument('--structure', default='{artist}/{album}')
    p_org.add_argument('--dry-run', action='store_true')

    # audit
    p_audit = sub.add_parser('audit', help='Find files with missing tags')
    p_audit.add_argument('path', help='Directory')
    p_audit.add_argument('--require', default='title,artist,album')
    p_audit.add_argument('-r', '--recursive', action='store_true')

    # strip
    p_strip = sub.add_parser('strip', help='Remove all tags')
    p_strip.add_argument('path', help='File or directory')
    p_strip.add_argument('-r', '--recursive', action='store_true')
    p_strip.add_argument('--dry-run', action='store_true')

    # export
    p_export = sub.add_parser('export', help='Export tags to JSON')
    p_export.add_argument('path', help='Directory')
    p_export.add_argument('-r', '--recursive', action='store_true')

    # import
    p_import = sub.add_parser('import', help='Import tags from JSON backup')
    p_import.add_argument('json_file', help='JSON file')

    # csv-import
    p_csv = sub.add_parser('csv-import', help='Import tags from CSV')
    p_csv.add_argument('csv_file', help='CSV file')

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        return 1

    commands = {
        'read': cmd_read, 'scan': cmd_scan, 'write': cmd_write,
        'batch-tag': cmd_batch_tag, 'rename': cmd_rename, 'organize': cmd_organize,
        'audit': cmd_audit, 'strip': cmd_strip, 'export': cmd_export,
        'import': cmd_import_tags, 'csv-import': cmd_csv_import,
    }
    return commands[args.command](args)

if __name__ == '__main__':
    sys.exit(main())
