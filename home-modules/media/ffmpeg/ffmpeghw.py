import glob
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys


class UsageError(Exception):
    pass


OPTIONS_WITHOUT_VALUES = {
    '-y', '-n', '-hide_banner', '-stats', '-nostats', '-stdin', '-nostdin',
    '-an', '-vn', '-sn', '-dn', '-re', '-copyts', '-start_at_zero', '-shortest',
    '-benchmark', '-benchmark_all', '-bitexact', '-accurate_seek', '-noaccurate_seek',
    '-autorotate', '-noautorotate', '-autoscale', '-noautoscale', '-copyinkf',
    '-ignore_unknown', '-copy_unknown', '-report', '-debug_ts', '-dump', '-hex',
    '-auto_conversion_filters', '-noauto_conversion_filters', '-vstats',
}
CODECS = {'h264', 'hevc', 'av1'}
VIDEO_OPTIONS = {'-vcodec', '-c:v', '-codec:v'}
FILTER_OPTIONS = {'-vf', '-filter:v'}
HARDWARE_OPTIONS = {'-vaapi_device', '-init_hw_device', '-filter_hw_device',
                    '-hwaccel', '-hwaccel_device', '-hwaccel_output_format'}


def fail(message):
    raise UsageError(message + '; use ffmpeg for explicit hardware pipelines')


def tokens(args):
    result = []
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == '-' or not arg.startswith('-'):
            result.append((i, None, arg))
            i += 1
        elif arg in OPTIONS_WITHOUT_VALUES:
            result.append((i, arg, None))
            i += 1
        else:
            if i + 1 == len(args):
                fail('missing value for ' + arg)
            result.append((i, arg, args[i + 1]))
            i += 2
    return result


def resolve_device(value):
    if value is None:
        return None
    if value.startswith('/dev/'):
        return value if Path(value).exists() else None
    if re.fullmatch(r'[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]', value):
        value = '0000:' + value
    paths = glob.glob('/dev/dri/by-path/pci-' + value + '-render')
    return paths[0] if paths else None


def profile(codec, bits):
    return {'h264': 'VAProfileH264',
            'hevc': 'VAProfileHEVCMain10' if bits == 10 else 'VAProfileHEVCMain ',
            'av1': 'VAProfileAV1Profile0',
            'vp9': 'VAProfileVP9Profile2' if bits == 10 else 'VAProfileVP9Profile0',
            'mpeg2video': 'VAProfileMPEG2'}.get(codec)


def capabilities(config, device):
    p = subprocess.run([config['vainfo'], '--display', 'drm', '--device', device],
                       capture_output=True, text=True, timeout=15)
    return p.stdout + p.stderr if p.returncode == 0 else ''


def supports(info, codec, bits, entry):
    name = profile(codec, bits)
    return name is not None and any(name in line and entry in line
                                   for line in info.splitlines())


def input_info(config, source):
    # Probing streams or network sources could consume data or open them twice.
    if not Path(source).is_file():
        fail('automatic acceleration requires a local input file')
    p = subprocess.run([config['ffprobe'], '-v', 'error', '-select_streams', 'v:0',
                        '-show_entries', 'stream=codec_name,pix_fmt', '-of', 'json',
                        source], capture_output=True, text=True, timeout=30)
    if p.returncode:
        fail('could not probe input video')
    streams = json.loads(p.stdout).get('streams', [])
    if not streams:
        fail('input has no video')
    fmt = streams[0].get('pix_fmt', '')
    if fmt not in {'yuv420p', 'yuvj420p', 'nv12', 'yuv420p10le', 'p010le'}:
        fail('unsupported automatic input pixel format ' + fmt)
    return streams[0]['codec_name'], 10 if fmt in {'yuv420p10le', 'p010le'} else 8


def cuda_probe(config, args):
    p = subprocess.run([config['ffmpeg'], '-hide_banner', '-nostdin', '-v', 'error',
                        '-init_hw_device', 'cuda=gpu:' + str(config['cudaDevice']),
                        '-filter_hw_device', 'gpu', *args],
                       capture_output=True, text=True, timeout=30)
    return p.returncode == 0, p.stderr.strip()


def prepare(config, args):
    # Explicit encoders and information commands retain FFmpeg's original behaviour.
    selected = any(a in VIDEO_OPTIONS and i + 1 < len(args) and args[i + 1] in CODECS
                   for i, a in enumerate(args))
    if not selected:
        return args, None
    ts = tokens(args)
    if any(opt and (opt.split(':')[0] in HARDWARE_OPTIONS) for _, opt, _ in ts):
        fail('automatic and explicit hardware options cannot be combined')
    inputs = [(i, value) for i, opt, value in ts if opt == '-i']
    outputs = [(i, value) for i, opt, value in ts if opt is None]
    if len(inputs) != 1 or len(outputs) != 1:
        fail('automatic acceleration supports one input and one output')
    inp, source = inputs[0]
    output, _ = outputs[0]
    if output != len(args) - 1 or output < inp:
        fail('put the single output filename last')
    if any(opt in {'-filter_complex', '-filter_complex_script', '-lavfi',
                   '-filter_script:v', '-filter'}
           for _, opt, _ in ts):
        fail('complex filter graphs require explicit hardware setup')
    if any(opt and (opt.startswith(('-c:v:', '-codec:v:', '-filter:v:', '-pix_fmt:')))
           for _, opt, _ in ts):
        fail('per-stream video settings require explicit hardware setup')
    encoders = [(i, value) for i, opt, value in ts
                if opt in VIDEO_OPTIONS and i > inp]
    if not encoders:
        fail('put the video encoder after the input')
    codec_index, codec = encoders[-1]
    if codec not in CODECS or any(opt == '-vn' for _, opt, _ in ts):
        return args, None
    if any(opt in {'-c', '-codec'} for _, opt, _ in ts):
        fail('combine video acceleration with separate audio/subtitle codec options')
    backend = config['type']
    software_options = {'-crf', '-preset', '-tune'} if backend == 'vaapi' else {'-crf'}
    if any(opt and opt.split(':')[0] in software_options for _, opt, _ in ts):
        fail('software encoder tuning cannot be translated to ' + backend)
    filters = [(i, value) for i, opt, value in ts if opt in FILTER_OPTIONS]
    if len(filters) > 1 or any(i < inp for i, _ in filters):
        fail('use one output video filter chain')
    vf = filters[0][1] if filters else ''
    sizes = [(i, value) for i, opt, value in ts
             if opt in {'-s', '-s:v'} and i > inp]
    if sizes:
        vf += (',' if vf else '') + 'scale=size=' + sizes[-1][1]
    if re.search(r'hwupload|hwdownload|hwmap|_(vaapi|cuda|vulkan|qsv|opencl)\b', vf):
        fail('hardware filters require explicit hardware setup')
    source_codec, source_bits = input_info(config, source)
    bits = 8 if codec == 'h264' else source_bits
    pixel_options = [(i, value) for i, opt, value in ts if opt == '-pix_fmt']
    if any(i < inp for i, _ in pixel_options):
        fail('input pixel-format overrides require explicit hardware setup')
    if pixel_options:
        fmt = pixel_options[-1][1]
        if fmt not in {'nv12', 'yuv420p', 'p010le', 'yuv420p10le'}:
            fail('automatic output supports only 8-bit or 10-bit 4:2:0')
        bits = 10 if fmt in {'p010le', 'yuv420p10le'} else 8
    if codec == 'h264' and bits != 8:
        fail('H.264 hardware output requires 8-bit pixels')
    explicit_decoder = any(opt in VIDEO_OPTIONS and i < inp for i, opt, _ in ts)
    gpu_decode = not vf and not explicit_decoder and source_bits == bits
    fmt = 'p010le' if bits == 10 else 'nv12'
    if backend == 'vaapi':
        nodes = sorted(glob.glob('/dev/dri/renderD*'))
        igpu = resolve_device(config['igpu'])
        egpu = resolve_device(config['egpu'])
        if not igpu and not egpu:
            if len(nodes) != 1:
                fail('set modules.media.ffmpeg.acceleration.igpu and .egpu for multiple GPUs')
            igpu = egpu = nodes[0]
        preferred = [igpu, egpu] if codec == 'av1' else [egpu, igpu]
        device = None
        info = ''
        for candidate in dict.fromkeys(p for p in preferred if p):
            candidate_info = capabilities(config, candidate)
            if supports(candidate_info, codec, bits, 'VAEntrypointEncSlice'):
                device, info = candidate, candidate_info
                break
        if not device:
            fail('no configured GPU supports the requested encoder/profile')
        gpu_decode = (gpu_decode and codec != 'h264'
                      and supports(info, source_codec, source_bits, 'VAEntrypointVLD'))
        encoder = codec + '_vaapi'
        decoder_backend = 'VA-API'
    else:
        device = str(config['cudaDevice'])
        encoder = codec + '_nvenc'
        decoder_backend = 'NVDEC/CUDA'
        ok, error = cuda_probe(config, [
            '-f', 'lavfi', '-i', 'color=size=1280x720', '-frames:v', '1',
            '-vf', 'format=' + fmt + ',hwupload', '-c:v', encoder,
            '-f', 'null', '-'])
        if not ok:
            fail('CUDA device ' + device + ' cannot encode ' + codec
                 + ' at ' + str(bits) + ' bits: ' + (error.splitlines()[0] if error else 'probe failed'))
        if gpu_decode:
            gpu_decode, _ = cuda_probe(config, [
                '-hwaccel', 'cuda', '-hwaccel_device', 'gpu',
                '-hwaccel_output_format', 'cuda', '-i', source,
                '-frames:v', '1', '-an', '-sn', '-vf', 'hwdownload,format=' + fmt,
                '-f', 'null', '-'])
    additions = []
    if gpu_decode:
        additions = ['-hwaccel', backend, '-hwaccel_device', 'gpu',
                     '-hwaccel_output_format', backend]
    else:
        vf = (vf + ',' if vf else '') + 'format=' + fmt + ',hwupload'
    rewritten = ['-init_hw_device', backend + '=gpu:' + device, '-filter_hw_device', 'gpu']
    remove = {i for i, _ in pixel_options + filters + sizes}
    for i, opt, value in ts:
        if i in remove:
            continue
        if i == inp:
            rewritten.extend(additions)
        if opt is None:
            if vf:
                rewritten.extend(['-vf', vf])
            rewritten.append(value)
        elif value is None:
            rewritten.append(opt)
        else:
            rewritten.extend([opt, encoder if i == codec_index else value])
    device_label = 'CUDA device ' + device if backend == 'cuda' else device
    decoder = source_codec + (' (' + decoder_backend + ' on ' + device_label + ')'
                              if gpu_decode else ' (CPU)')
    summary = 'decode: ' + decoder + '; encode: ' + encoder + ' (on ' + device_label + ')'
    return rewritten, summary


def info_logging_enabled(args):
    levels = {'quiet': -8, 'panic': 0, 'fatal': 8, 'error': 16, 'warning': 24,
              'info': 32, 'verbose': 40, 'debug': 48, 'trace': 56}
    level = 32
    for i, arg in enumerate(args[:-1]):
        if arg not in {'-v', '-loglevel'}:
            continue
        # Logging flags such as repeat and level do not change verbosity.
        for part in re.findall(r'[+-]?[^+-]+', args[i + 1]):
            if part.lstrip('+') in levels:
                level = levels[part.lstrip('+')]
            elif re.fullmatch(r'[+-]?\d+', part):
                level = int(part)
    return level >= 32


def main():
    config = json.loads(Path(sys.argv[1]).read_text())
    try:
        args = sys.argv[2:]
        rewritten, summary = prepare(config, args)
        command = [config['ffmpeg']] + rewritten
        if os.environ.get('FFMPEG_GPU_DRY_RUN') == '1':
            print(shlex.join(command))
        elif summary is None:
            os.execv(command[0], command)
        else:
            child = subprocess.Popen(command)
            while True:
                try:
                    status = child.wait()
                    break
                except KeyboardInterrupt:
                    # Terminal interrupts also reach FFmpeg in the same process group.
                    continue
            if status == 0 and info_logging_enabled(args):
                print('ffmpeghw: ' + summary, file=sys.stderr)
            sys.exit(status if status >= 0 else 128 - status)
    except (UsageError, subprocess.TimeoutExpired) as error:
        print('ffmpeghw: ' + str(error), file=sys.stderr)
        sys.exit(2)


if __name__ == '__main__':
    main()
