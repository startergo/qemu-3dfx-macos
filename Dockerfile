FROM archlinux:latest

ARG COMMIT_ID=0000000

RUN sed -i 's/^#DisableSandboxSyscalls/DisableSandboxSyscalls/' /etc/pacman.conf && \
    pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed \
        base-devel \
        git \
        dos2unix \
        xorriso \
        wget \
        unzip \
        vim \
        mingw-w64-gcc \
        mingw-w64-binutils \
        mesa \
        freeglut \
        perl \
    && pacman -Sc --noconfirm

# Find where gendef is installed and symlink it
RUN find / -name '*gendef*' -type f 2>/dev/null; \
    GENDUP=$(find / -name '*gendef*' -type f 2>/dev/null | head -1); \
    if [ -n "$GENDUP" ]; then \
        ln -sf "$GENDUP" /usr/local/bin/gendef && echo "Linked: $GENDUP -> /usr/local/bin/gendef"; \
    else \
        echo "gendef not found, installing from AUR..." && \
        pacman -S --noconfirm --needed autoconf automake bison flex && \
        cd /tmp && \
        git clone --depth 1 https://github.com/mirror/mingw-w64.git && \
        cd mingw-w64/mingw-w64-tools/gendef && \
        ./configure --prefix=/usr/local && make && make install && \
        cd /tmp && rm -rf mingw-w64; \
    fi; \
    which gendef

# shasum is a Perl utility not always in PATH — provide a wrapper
RUN printf '#!/bin/sh\nexec sha256sum "$@"\n' > /usr/local/bin/shasum && \
    chmod +x /usr/local/bin/shasum

# Download and set up Open Watcom (DOS32 OVL wrapper toolchain)
RUN cd /opt && \
    wget -q https://github.com/open-watcom/open-watcom-v2/releases/download/2025-01-03-Build/ow-snapshot.tar.xz && \
    mkdir watcom && \
    tar xf ow-snapshot.tar.xz -C watcom && \
    rm ow-snapshot.tar.xz

# Download and set up DJGPP (DXE wrapper toolchain)
RUN cd /opt && \
    wget -q https://github.com/andrewwutw/build-djgpp/releases/download/v3.4/djgpp-mingw-gcc1220.zip && \
    unzip -q djgpp-mingw-gcc1220.zip -d djgpp && \
    find djgpp -name 'dxe3gen*' -exec cp {} djgpp/bin/ \; 2>/dev/null; \
    find djgpp -name 'dxe3bind*' -exec cp {} djgpp/bin/ \; 2>/dev/null; \
    rm djgpp-mingw-gcc1220.zip

# Set Watcom environment
ENV WATCOM=/opt/watcom
ENV EDPATH=/opt/watcom/eddat
ENV PATH="/opt/watcom/binl:/opt/djgpp/bin:${PATH}"

# Copy source (build context = repo root)
COPY qemu-3dfx-arch/ /build/qemu-3dfx-arch/

WORKDIR /build

# Init git repo so build scripts can read commit hash
RUN cd /build/qemu-3dfx-arch && \
    rm -rf .git && \
    git init && \
    git config user.email "build@docker" && \
    git config user.name "Build" && \
    git add -A && \
    git commit -m "build" --quiet

# Build 3dfx wrappers (Glide: DLL, VXD, DXE, OVL)
# OVL and DXE may fail on some toolchain versions — tolerate errors
RUN cd qemu-3dfx-arch/wrappers/3dfx && \
    mkdir -p build && cd build && \
    bash ../../../scripts/conf_wrapper && \
    make || true && make clean

# Build Mesa wrappers (OpenGL: DLL, EXE)
RUN cd qemu-3dfx-arch/wrappers/mesa && \
    mkdir -p build && cd build && \
    bash ../../../scripts/conf_wrapper && \
    make all+ || true && make clean

# Build OpenGlide extras (Linux platform needs GL/X11 — may fail, tolerate)
RUN cd qemu-3dfx-arch/wrappers/extra/openglide && \
    dos2unix configure.ac Makefile.am && \
    bash ./bootstrap && \
    mkdir -p ../build && cd ../build && \
    ../openglide/configure --disable-sdl && make

# Build g2xwrap (expects MSYSTEM=MINGW32 and uses mingw g++)
# Makefile hardcodes g++ and expects libglide2x.dll from OpenGlide build;
# patch for cross-compilation: provide the DLL from 3dfx build, use mingw g++,
# and fix sdk2_unix.h which was configured for 64-bit Linux (FXSIZEOF_INT_P=8)
RUN cd qemu-3dfx-arch/wrappers/extra && \
    mkdir -p build/.libs && \
    cp ../3dfx/build/glide2x.dll build/.libs/libglide2x.dll 2>/dev/null || true && \
    sed -i 's/FXSIZEOF_INT_P.*8/FXSIZEOF_INT_P              4/' build/sdk2_unix.h 2>/dev/null || true && \
    cd g2xwrap && \
    sed -i 's/@g++/@$(CXX)/g' Makefile && \
    MSYSTEM=MINGW32 make CXX=i686-w64-mingw32-g++ DLLTOOL=i686-w64-mingw32-dlltool \
      CFLAGS="-I../build -I../openglide -I. -Os -fomit-frame-pointer -DFXSIZEOF_INT_P=4" || echo "g2xwrap build incomplete"

# Package ISO
RUN cd qemu-3dfx-arch/wrappers/iso && \
    mkdir -p wrapgl/icd wrapfx g2xwrap && \
    cp -rf ../3dfx/build/*.vxd ../3dfx/build/*.sys ../3dfx/build/*.dll \
           ../3dfx/build/*.dxe ../3dfx/build/*.ovl ../3dfx/build/*.exe \
           ./wrapfx/ 2>/dev/null || true && \
    cp -rf ../mesa/build/*.dll ../mesa/build/*.exe ./wrapgl/ 2>/dev/null || true && \
    cp -rf ../extra/g2xwrap/*.dll g2xwrap/ 2>/dev/null || true && \
    bash ../../scripts/sign_binary && \
    cp ../texts/readme.txt readme.txt && \
    cp ../../LICENSE license.txt && \
    cp -rf ../texts/readme_icd.txt ../mesa/registry/*.reg wrapgl/icd && \
    mv wrapgl/icd/readme_icd.txt wrapgl/icd/readme.txt && \
    mv wrapgl/qmfxgl32.dll wrapgl/icd/qmfxgl32.dll 2>/dev/null || true && \
    unix2dos commit.txt license.txt readme.txt autorun.inf open.bat \
             wrapgl/icd/readme.txt wrapgl/icd/*.reg 2>/dev/null || true && \
    cd .. && \
    xorriso -as mkisofs -JR -V "VMWRAPPER-${COMMIT_ID}" -o wrappers.iso iso

# Override commit.txt with main repo commit ID (not submodule)
RUN cd /build/qemu-3dfx-arch/wrappers/iso && \
    cat > commit.txt <<EOF
QEMU-3dfx-arch VMAddons ISO
=================================================
Commit ${COMMIT_ID}

refer to readme.txt for more information
EOF

# Rebuild ISO with correct commit
RUN cd /build/qemu-3dfx-arch/wrappers && \
    unix2dos iso/commit.txt && \
    xorriso -as mkisofs -JR -V "VMWRAPPER-${COMMIT_ID}" -o wrappers.iso iso

# Copy output on run
CMD ["sh", "-c", "cp /build/qemu-3dfx-arch/wrappers/wrappers.iso /output/ && echo 'Done: /output/wrappers.iso'"]
