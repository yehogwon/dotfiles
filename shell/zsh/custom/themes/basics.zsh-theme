# fork of crcandy
if [[ -n "$SLURM_JOB_ID" ]]; then
  basics_identity_color="%{$fg_bold[red]%}"
  basics_slurm_segment="%{$fg[red]%}[$SLURM_JOB_ID]%{$reset_color%} "
else
  basics_identity_color="%{$fg_bold[green]%}"
  basics_slurm_segment=""
fi

PROMPT='${basics_identity_color}%n@%m %{$fg[blue]%}%D{[%H:%M:%S]} ${basics_slurm_segment}%{$reset_color%}%{$fg[white]%}[%~]%{$reset_color%} $(git_prompt_info)
%{$fg[blue]%}->%{$fg_bold[blue]%} %#%{$reset_color%} '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[green]%}["
ZSH_THEME_GIT_PROMPT_SUFFIX="]%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}*%{$fg[green]%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""
