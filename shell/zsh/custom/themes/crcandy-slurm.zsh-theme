# fork of crcandy
PROMPT=''

if [[ -n "$SLURM_JOB_ID" ]]; then
  PROMPT+='%{$fg_bold[yellow]%}%n@%m '
else
  PROMPT+='%{$fg_bold[green]%}%n@%m '
fi

PROMPT+='%{$fg[blue]%}%D{[%H:%M:%S]} '
PROMPT+='%{$fg[white]%}[%~]%{$reset_color%} '
PROMPT+='$(git_prompt_info)'
PROMPT+=$'\n'

if [[ -n "$SLURM_JOB_ID" ]]; then
  PROMPT+='%{$fg[yellow]%}[$SLURM_JOB_ID]%{$reset_color%} '

  if [[ -n "$SLURM_GPUS_ON_NODE" ]]; then
    PROMPT+="%{$fg[yellow]%}[gpu:${SLURM_GPUS_ON_NODE}]%{$reset_color%} "
  fi

  if [[ -n "$SLURM_CPUS_PER_TASK" ]]; then
    PROMPT+="%{$fg[yellow]%}[cpu:${SLURM_CPUS_PER_TASK}]%{$reset_color%} "
  elif [[ -n "$SLURM_JOB_CPUS_PER_NODE" ]]; then
    PROMPT+="%{$fg[yellow]%}[cpu:${${SLURM_JOB_CPUS_PER_NODE%%,*}%%\(*}]%{$reset_color%} "
  fi

  PROMPT+=$'\n'
fi

PROMPT+='%{$fg[blue]%}->%{$fg_bold[blue]%} %#%{$reset_color%} '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[green]%}["
ZSH_THEME_GIT_PROMPT_SUFFIX="]%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}*%{$fg[green]%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""
