#!/usr/bin/env python3
"""Package only reviewed source paths, the built app ZIP, and release notes."""
import hashlib, json, pathlib, plistlib, shutil, sys, zipfile
root = pathlib.Path(__file__).resolve().parents[1]
info = plistlib.loads((root / 'Resources/Info.plist').read_bytes())
version = info['CFBundleShortVersionString']
arch = sys.argv[1] if len(sys.argv) > 1 else 'arm64'
if arch not in ('arm64', 'x86_64'): raise SystemExit('Expected arm64 or x86_64')
output = root / 'dist' / f'Luma-{version}-release'
output.mkdir(exist_ok=True)
app_name = f'Luma-{version}-macOS-{arch}.zip'
shutil.copyfile(root / 'dist' / f'Luma-macOS-{arch}.zip', output / app_name)
source_name = f'Luma-{version}-source.zip'
with zipfile.ZipFile(output / source_name, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in ('Sources', 'Tests', 'Resources', 'scripts', 'patches', 'docs', 'Package.swift', 'README.md', 'LICENSE', 'SECURITY.md', '.gitignore', '.github'):
        base = root / name
        paths = sorted(base.rglob('*')) if base.is_dir() else [base]
        for path in paths:
            if not path.is_file() or path.is_symlink() or path.name == '.DS_Store' or '__pycache__' in path.parts: continue
            rel = path.relative_to(root)
            entry = zipfile.ZipInfo(f'Luma-{version}/{rel.as_posix()}')
            entry.external_attr = (0o100755 if path.stat().st_mode & 0o111 else 0o100644) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, path.read_bytes())
shutil.copyfile(root / 'docs' / f'RELEASE-{version}.md', output / 'SURUM-NOTLARI.md')
shutil.copyfile(root / 'LICENSE', output / 'LICENSE')
(output / 'KURULUM.md').write_text(f'''# Luma {version}

Bu paket {arch} mimarisi içindir. ARM64 Apple Silicon, x86_64 Intel anlamına gelir.

1. Luma uygulama ZIP’ini açıp Luma.app dosyasını Uygulamalar klasörüne taşıyın.
2. Mac bağlantısı için Bağlan’ı seçin; Discord ayrıca kurulu olmalıdır.
3. PS5 kurulumu sayfasına kendi konsolunuzun IPv4 adresini girin. İlk kurulumda alan boştur.
4. Paylaşım iznini macOS’un kendi penceresinden verin ve paylaşımı başlatın.
5. Ekranda oluşan ağ ayarlarını konsolda ayrı bir LAN profiline kaydedin. Normal otomatik profilinizi saklayın.

Mac ve konsol aynı IPv4 alt ağında olmalıdır; Mac Wi-Fi kullanabilir. Paylaşım sırasında Mac açık kalmalıdır. Normal bağlantıya dönmek için konsolda otomatik profili seçin.

Bu sürüm adayı varsayılan olarak ad-hoc imzalıdır; Apple noter onayı yoktur. Diğer Mac’lerde sorunsuz kurulum doğrulanmamıştır. Güvenlik denetimlerini kapatmayın. Genel dağıtım öncesinde kaynak paketteki docs/DISTRIBUTION.md adımlarını tamamlayın.

Kaynak kod, kullanım ve güvenlik belgeleri source.zip içindedir. Bileşen lisansları uygulamanın Hakkında bölümünde bulunur. Kişisel konsol profili ve yerel günlükler pakete dahil edilmez.
''')
manifest = {'product':'Luma','version':version,'build':info['CFBundleVersion'],'architecture':arch,'notarized':False,'signing':'adhoc development candidate','profiles_included':False}
(output / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
files = sorted(p for p in output.iterdir() if p.is_file() and p.name != 'SHA256SUMS.txt')
(output / 'SHA256SUMS.txt').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in files))
outer = root / 'dist' / f'Luma-{version}-release-pack.zip'
with zipfile.ZipFile(outer, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(output.iterdir()):
        if path.is_file(): archive.write(path, f'{output.name}/{path.name}')
print(outer)
