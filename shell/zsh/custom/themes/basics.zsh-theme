# fork of crcandy
PROMPT=''

if [[ -n "$SLURM_JOB_ID" ]]; then
  PROMPT+='%{$fg_bold[yellow]%}%n@%m '
  PROMPT+='%{$fg[yellow]%}[$SLURM_JOB_ID]%{$reset_color%} '
else
  PROMPT+='%{$fg_bold[green]%}%n@%m '
fi

PROMPT+='%{$fg[blue]%}%D{[%H:%M:%S]} '
PROMPT+='%{$fg[white]%}[%~]%{$reset_color%} '
PROMPT+='$(git_prompt_info)'
PROMPT+=$'\n'
PROMPT+='%{$fg[blue]%}->%{$fg_bold[blue]%} %#%{$reset_color%} '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[green]%}["
ZSH_THEME_GIT_PROMPT_SUFFIX="]%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}*%{$fg[green]%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""
