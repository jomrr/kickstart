%post --interpreter=/usr/bin/bash --log=/root/ks-post-neovim-default-editor.log
dnf -y install neovim

alternatives --install /usr/bin/vi vi /usr/bin/nvim 60
alternatives --install /usr/bin/vim vim /usr/bin/nvim 60
alternatives --install /usr/bin/editor editor /usr/bin/nvim 60
alternatives --set vi /usr/bin/nvim
alternatives --set vim /usr/bin/nvim
alternatives --set editor /usr/bin/nvim

echo "export EDITOR='/usr/bin/nvim'" | tee /etc/profile.d/editor.sh
echo "export VISUAL='/usr/bin/nvim'" | tee /etc/profile.d/visual.sh

mkdir -p /etc/xdg/nvim
cat << EOF > /etc/xdg/nvim/sysinit.vim
" General settings
colorscheme default

syntax on
set mouse=
set nonumber
set noswapfile
set paste

" Default indentation settings
set tabstop=4
set shiftwidth=4
set expandtab

" Filetype-specific indentation settings
augroup FiletypeIndent
    autocmd!
    
    " HTML, CSS, and related settings
    autocmd FileType html,css,scss,xml setlocal tabstop=2 shiftwidth=2 expandtab

    " JavaScript and TypeScript settings
    autocmd FileType javascript,typescript setlocal tabstop=2 shiftwidth=2 expandtab

    " JSON settings
    autocmd FileType json setlocal tabstop=2 shiftwidth=2 expandtab

    " Lua settings
    autocmd FileType lua setlocal tabstop=2 shiftwidth=2 expandtab

    " Makefile settings (Makefiles should use tabs, not spaces)
    autocmd FileType make setlocal noexpandtab tabstop=8 shiftwidth=8

    " Markdown settings
    autocmd FileType markdown setlocal tabstop=4 shiftwidth=4 expandtab

    " PHP settings
    autocmd FileType php setlocal tabstop=4 shiftwidth=4 expandtab

    " Python settings
    autocmd FileType python setlocal tabstop=4 shiftwidth=4 expandtab

    " Shell script settings
    autocmd FileType bash setlocal tabstop=4 shiftwidth=4 expandtab
    autocmd FileType sh setlocal tabstop=4 shiftwidth=4 expandtab

    " YAML settings
    autocmd FileType yaml setlocal tabstop=2 shiftwidth=2 expandtab
augroup END
EOF
%end
