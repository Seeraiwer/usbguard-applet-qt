pkgname=usbguard-applet-qt-git
_pkgname=usbguard-applet-qt
pkgver=0.7.4.r71.g8d45ad3
pkgrel=1
pkgdesc="Qt applet for interacting with the USBGuard daemon"
arch=('x86_64')
url="https://github.com/seeraiwer/usbguard-applet-qt"
license=('GPL-2.0-or-later')
depends=('qt6-base' 'qt6-svg' 'usbguard' 'hicolor-icon-theme')
makedepends=('git' 'cmake' 'qt6-tools' 'pkgconf')
provides=("$_pkgname")
conflicts=("$_pkgname")
source=("$_pkgname::git+https://github.com/seeraiwer/usbguard-applet-qt.git")
sha256sums=('SKIP')

pkgver() {
  cd "$srcdir/$_pkgname"
  local tag
  if tag=$(git describe --long --tags 2>/dev/null); then
    # Upstream tags look like "usbguard-0.7.4" (or "v0.3"): strip the prefix
    # and turn the git-describe suffix into "0.7.4.r<N>.g<sha>".
    printf '%s\n' "$tag" | sed 's/^usbguard-//;s/^v//;s/\([^-]*-g\)/r\1/;s/-/./g'
  else
    # Fork has no tags reachable: fall back to "0.r<commits>.g<short-sha>".
    printf '0.r%s.g%s\n' \
      "$(git rev-list --count HEAD)" \
      "$(git rev-parse --short=7 HEAD)"
  fi
}

build() {
  cmake -B build -S "$_pkgname" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=None
  cmake --build build
}

package() {
  DESTDIR="$pkgdir" cmake --install build
}
