#!/usr/bin/env python3
"""Convert comparison MP4s to looping GIFs for inline README previews."""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input-dir', type=Path, default=ROOT / 'docs/media')
    parser.add_argument('--width', type=int, default=300)
    parser.add_argument('--fps', type=int, default=12)
    args = parser.parse_args()
    if args.width <= 0 or args.fps <= 0:
        parser.error('width and fps must be positive')
    for source in sorted(args.input_dir.glob('*.mp4')):
        destination = source.with_suffix('.gif')
        filters = (f'fps={args.fps},scale={args.width}:-1:flags=lanczos,split[s0][s1];'
                   '[s0]palettegen=stats_mode=diff[p];'
                   '[s1][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle')
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                        '-threads', '2', '-i', str(source),
                        '-filter_complex_threads', '1', '-filter_complex', filters,
                        '-loop', '0', str(destination)], check=True)
        print(destination.name, destination.stat().st_size, 'bytes')
