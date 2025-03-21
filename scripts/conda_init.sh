shell_name=$SHELL

# >>> conda initialize >>>
if [ -x "$HOME/miniconda3/bin/conda" ]; then
    CONDA_INSTALLED_PATH="$HOME/miniconda3"
elif [ -x "/opt/ohpc/pub/apps/anaconda3/bin/conda" ]; then
    CONDA_INSTALLED_PATH="/opt/ohpc/pub/apps/anaconda3"
fi

if [ -n "$CONDA_INSTALLED_PATH" ]; then
    if [ -x "$CONDA_INSTALLED_PATH/bin/conda" ]; then
        __conda_setup="$("$CONDA_INSTALLED_PATH/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
        if [ $? -eq 0 ]; then
            eval "$__conda_setup"
        else
            if [ -f "$CONDA_INSTALLED_PATH/etc/profile.d/conda.sh" ]; then
                . "$CONDA_INSTALLED_PATH/etc/profile.d/conda.sh"
            else
                export PATH="$CONDA_INSTALLED_PATH/bin:$PATH"
            fi
        fi
        unset __conda_setup
    fi
else
    echo "Automatic conda search failed. Please set CONDA_INSTALLED_PATH manually."
fi
# >>> conda initialize >>>
