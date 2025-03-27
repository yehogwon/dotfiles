shell_name=$(basename $SHELL)

# >>> conda initialize >>>
_CANDIDATE_PATHS=(
    "/usr/local/Caskroom/miniconda" # macos (homebrew)
    "$HOME/miniconda3" # linux
    "/opt/ohpc/pub/apps/anaconda3" # linux (ohpc)
)

for CANDIDATE_PATH in "${_CANDIDATE_PATHS[@]}"; do
    if [ -d "$CANDIDATE_PATH" ]; then
        CONDA_INSTALLED_PATH="$CANDIDATE_PATH"
        break
    fi
done

unset _CANDIDATE_PATHS

if [ -n "$CONDA_INSTALLED_PATH" ]; then
    if [ -x "$CONDA_INSTALLED_PATH/bin/conda" ]; then
        __conda_setup="$("$CONDA_INSTALLED_PATH/bin/conda" 'shell.${shell_name}' 'hook' 2> /dev/null)"
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
