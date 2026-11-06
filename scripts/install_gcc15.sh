#/bin/bash 

sudo apt install libgmp-dev libmpfr-dev libmpc-dev libisl-dev flex bison texinfo build-essential

cd ~/lib
git ls-remote --tags https://gcc.gnu.org/git/gcc.git 'refs/tags/releases/gcc-15.*' | tail -5
git clone --depth 1 --branch releases/gcc-15.2.0 https://gcc.gnu.org/git/gcc.git gcc-15

cd ~/lib/gcc-15
mkdir build && cd build
../configure --prefix=/opt/gcc-15 --program-suffix=-15 \
  --enable-languages=c,c++ --disable-multilib --disable-bootstrap
make -j$(nproc)
sudo make install

echo /opt/gcc-15/lib64 | sudo tee /etc/ld.so.conf.d/gcc-15.conf
sudo ldconfig
/opt/gcc-15/bin/g++-15 --version
