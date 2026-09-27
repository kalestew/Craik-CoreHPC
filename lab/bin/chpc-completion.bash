# shellcheck shell=bash
# Tab completion for chpc-tool, chpc-assets and chpc-jobstats. Sourced, not run:
#
#   . lab/bin/chpc-completion.bash
#
# env.sh and chpc.env do that for an interactive shell, so there is nothing to
# install: the ~/.bashrc line from the root README is enough on the cluster.
#
# Self-contained on purpose: no bash-completion package, nothing newer than
# bash 3.2 (the lab Macs), and it works in zsh through bashcompinit. Tool names
# come from the registry directories, so a completion costs no subprocess; the
# fallback to `chpc-tool list` covers a shell that sourced the FAC chpc.env
# with no tools/ copy beside it.

# zsh: make `complete`, COMPREPLY and compgen exist.
if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -Uz +X compinit bashcompinit 2>/dev/null
  compinit -u 2>/dev/null
  bashcompinit 2>/dev/null
fi
# A shell without `complete` (plain sh, or a zsh where bashcompinit failed)
# gets nothing, silently.
if ! command -v complete >/dev/null 2>&1; then
  return 0 2>/dev/null || exit 0
fi

_chpc_tool_names() {
  # Registry directories via $CHPC_TOOLS, which env.sh and chpc.env both export.
  local d n found=0
  [ -n "${ZSH_VERSION:-}" ] && setopt localoptions nullglob 2>/dev/null
  for d in "${CHPC_TOOLS:-/nonexistent}"/*/tool.conf; do
    [ -e "$d" ] || continue
    n=${d%/tool.conf}; n=${n##*/}
    case $n in _*) continue ;; esac      # _template and friends
    printf '%s\n' "$n"; found=1
  done
  # No registry beside this shell: ask the tool, which resolves its own.
  [ "$found" = 1 ] || chpc-tool list 2>/dev/null | awk 'NR > 1 { print $1 }'
}

_chpc_files() {
  # Default (file) completion for whatever follows a command. compopt is
  # bash 4; bash 3.2 and zsh get compgen -f.
  compopt -o default 2>/dev/null || COMPREPLY=( $(compgen -f -- "$1") )
}

_chpc_tool_complete() {
  local cur verb
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  verb=${COMP_WORDS[1]:-}
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W 'list show path export exec doctor test build publish wrapper help' -- "$cur") )
    return 0
  fi
  case $verb in
    show)
      if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "--env $(_chpc_tool_names)" -- "$cur") )
      elif [ "${COMP_WORDS[2]}" = "--env" ]; then
        COMPREPLY=( $(compgen -W "$(_chpc_tool_names)" -- "$cur") )
      fi ;;
    path|build|publish|wrapper)
      [ "$COMP_CWORD" -eq 2 ] && COMPREPLY=( $(compgen -W "$(_chpc_tool_names)" -- "$cur") ) ;;
    export|doctor|test)
      COMPREPLY=( $(compgen -W "$(_chpc_tool_names)" -- "$cur") ) ;;
    exec)
      if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "$(_chpc_tool_names)" -- "$cur") )
      elif [ "$COMP_CWORD" -eq 3 ]; then
        # The one form the docs teach: chpc-tool exec <tool> -- <program> ...
        COMPREPLY=( $(compgen -W '--' -- "$cur") )
      else
        _chpc_files "$cur"
      fi ;;
  esac
  return 0
}

_chpc_assets_complete() {
  local cur prev verb
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  verb=${COMP_WORDS[1]:-}
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W 'list verify install record hash' -- "$cur") )
    return 0
  fi
  case $verb in
    list|verify)
      [ "$COMP_CWORD" -eq 2 ] && COMPREPLY=( $(compgen -W "$(_chpc_tool_names)" -- "$cur") ) ;;
    install)
      if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "$(_chpc_tool_names)" -- "$cur") )
      elif [ "$prev" = "--from" ]; then
        COMPREPLY=( $(compgen -d -- "$cur") )
      else
        COMPREPLY=( $(compgen -W '--from --record' -- "$cur") )
      fi ;;
    record)
      if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "$(_chpc_tool_names)" -- "$cur") )
      elif [ "$COMP_CWORD" -eq 3 ]; then
        COMPREPLY=( $(compgen -W '--dest' -- "$cur") )
      elif [ "$prev" != "--dest" ]; then
        _chpc_files "$cur"
      fi ;;
    hash)
      _chpc_files "$cur" ;;
  esac
  return 0
}

_chpc_jobstats_complete() {
  local cur
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  case ${COMP_WORDS[COMP_CWORD-1]} in
    --days) ;;                             # a number; nothing to offer
    *) COMPREPLY=( $(compgen -W '--mine --days --tasks --help' -- "$cur") ) ;;
  esac
  return 0
}

_chpc_globus_complete() {
  local cur prev
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W 'doctor env push pull' -- "$cur") )
  else
    case $prev in
      --sync-level) COMPREPLY=( $(compgen -W 'exists size mtime checksum' -- "$cur") ) ;;
      --type) COMPREPLY=( $(compgen -W 'file directory' -- "$cur") ) ;;
      --wait|--label|--exclude|--exclude-dir) ;;
      *) case $cur in
           -*) COMPREPLY=( $(compgen -W '--dry-run --wait --label --exclude --exclude-dir --sync-level --type --help' -- "$cur") ) ;;
           *) _chpc_files "$cur" ;;
         esac ;;
    esac
  fi
  return 0
}

_chpc_submit_complete() {
  local cur prev
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  case $prev in
    --wait|--corehpc) ;;
    *) case $cur in
         -*) COMPREPLY=( $(compgen -W '--dry-run --wait --corehpc --help --' -- "$cur") ) ;;
         *) _chpc_files "$cur" ;;
       esac ;;
  esac
  return 0
}

complete -F _chpc_tool_complete chpc-tool
complete -F _chpc_assets_complete chpc-assets
complete -F _chpc_jobstats_complete chpc-jobstats
complete -F _chpc_globus_complete chpc-globus.sh
complete -F _chpc_submit_complete chpc-submit.sh
