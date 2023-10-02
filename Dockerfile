FROM ubuntu:22.04

RUN echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections

USER root
RUN apt-get update \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install -y --no-install-recommends build-essential cpanminus git libbz2-dev libc6-dev libexpat1-dev libffi-dev libgdbm-dev liblzma-dev libncurses5-dev libncursesw5-dev libreadline-dev libsqlite3-dev libssl-dev libxml2 libxml2-dev libxslt1.1 libxslt1-dev llvm locales make python3-pygments tk-dev ttf-mscorefonts-installer zlib1g-dev \
  && apt-get clean autoclean \
  && apt-get autoremove -y


RUN cpanm File::HomeDir Pod::Usage YAML::Tiny

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /biber

RUN wget -qO - https://github.com/plk/biber/archive/v2.19/biber-2.19.tar.gz | tar xz --strip-components=1
RUN cpanm -f Net::HTTP
RUN cpanm LWP::UserAgent || exit 1
RUN cpanm LWP::Protocol::http || exit 1
RUN cpanm Net::HTTPS || exit 1
RUN cpanm LWP::Protocol::https || exit 1
RUN cpanm --installdeps . || exit 1
ENV LD_LIBRARY_PATH /usr/local/lib:$LD_LIBRARY_PATH

RUN perl Build.PL \
  && ./Build \
  && ./Build install

RUN rm -rf /biber

WORKDIR /texlive

ENV TEXDIR /usr/local/texlive
ENV TEXUSERDIR ~/.texlive
ENV TEXMFHOME /home/vscode/texmf
ENV TEXMFLOCAL $TEXDIR/texmf-local

RUN wget -qO - https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz | tar xz --strip-components=1 \
  && perl ./install-tl --no-interaction --scheme=basic --no-doc-install --no-src-install --texdir=$TEXDIR --texuserdir=$TEXUSERDIR
ENV PATH $TEXDIR/bin/aarch64-linux:$TEXDIR/bin/x86_64-linux:$PATH

RUN rm -rf /texlive

WORKDIR /home/vscode

RUN groupadd -g 1000 vscode && useradd -r -u 1000 -g vscode vscode

RUN chown -R vscode:vscode /home/vscode

RUN chown -R vscode:vscode $TEXDIR

USER vscode

RUN tlmgr update --self --all \
  && tlmgr install babel-german biblatex biblatex-apa booktabs caption csquotes etoolbox fancyvrb fontspec hyphen-german latexindent latexmk minted newfloat parskip ragged2e setspace sidecap titlesec upquote \
  && tlmgr update --all

RUN texhash $TEXMFHOME \
  && texhash $TEXMFLOCAL \
  && texhash $TEXDIR/texmf-dist

RUN tlmgr version \
  && latexmk -version \
  && texhash --version