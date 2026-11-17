########################################################################
#
# 96-ztag.zsh
#
# Create and push an annotated semantic-version Git tag from main.
# Git utility only: no dependency on GitHub or any release service.
#
########################################################################

function ztag
{
   emulate -L zsh
   setopt pipefail

   local option comment branch working_changes tag_list tag
   local highest new_version new_tag remainder
   local -i major minor patch
   local -a versions=()

   if (( $# != 2 )); then
      print -u2 -r -- 'Usage: ztag {-M|-m|-p|-v<major>.<minor>.<patch>} <comment>'
      return 2
   fi

   option=$1
   comment=$2

   case $option in
   -M|-m|-p)
      ;;
   -v*)
      new_version=${option#-v}
      if [[ ! $new_version =~ '^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)$' ]]; then
         print -u2 -r -- "ztag: invalid semantic version: $new_version"
         return 2
      fi
      ;;
   *)
      print -u2 -r -- 'Usage: ztag {-M|-m|-p|-v<major>.<minor>.<patch>} <comment>'
      return 2
      ;;
   esac

   if [[ -z ${comment//[[:space:]]/} ]]; then
      print -u2 -r -- 'ztag: a nonempty tag comment is required'
      return 2
   fi

   if [[ $(command git rev-parse --is-inside-work-tree 2>/dev/null) != true ]]; then
      print -u2 -r -- 'ztag: not inside a Git working tree'
      return 1
   fi

   branch=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null) || {
      print -u2 -r -- 'ztag: detached HEAD; current branch must be main'
      return 1
   }

   if [[ $branch != main ]]; then
      print -u2 -r -- "ztag: current branch is '$branch'; expected 'main'"
      return 1
   fi

   working_changes=$(command git status --porcelain=v1 --untracked-files=all) || {
      print -u2 -r -- 'ztag: unable to inspect the working tree'
      return 1
   }

   if [[ -n $working_changes ]]; then
      print -u2 -r -- 'ztag: working tree is not clean (staged, unstaged, or untracked changes)'
      return 1
   fi

   if ! command git remote get-url origin >/dev/null 2>&1; then
      print -u2 -r -- "ztag: Git remote 'origin' is not configured"
      return 1
   fi

   # Consider only strict vMAJOR.MINOR.PATCH tags, ignoring all other tags.
   tag_list=$(command git tag --list 'v*') || {
      print -u2 -r -- 'ztag: unable to list Git tags'
      return 1
   }

   for tag in ${(f)tag_list}; do
      if [[ $tag =~ '^v(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)$' ]]; then
         versions+=("$tag")
      fi
   done

   if (( ${#versions} == 0 )); then
      print -u2 -r -- 'ztag: no semantic-version tags found; create the first tag manually'
      return 1
   fi

   # GNU sort -V compares numeric version components, not tag dates.
   highest=$(print -rl -- "${versions[@]}" | LC_ALL=C command sort -V | command tail -n 1) || {
      print -u2 -r -- 'ztag: unable to determine the highest version'
      return 1
   }

   remainder=${highest#v}
   major=${remainder%%.*}
   remainder=${remainder#*.}
   minor=${remainder%%.*}
   patch=${remainder#*.}

   case $option in
   -M)
      (( ++major ))
      minor=0
      patch=0
      new_tag="v${major}.${minor}.${patch}"
      ;;
   -m)
      (( ++minor ))
      patch=0
      new_tag="v${major}.${minor}.${patch}"
      ;;
   -p)
      (( ++patch ))
      new_tag="v${major}.${minor}.${patch}"
      ;;
   -v*)
      new_tag="v${new_version}"
      ;;
   esac

   # Explicit versions must advance beyond the greatest existing version.
   if [[ $new_tag == $highest ]] ||
      [[ $(print -rl -- "$highest" "$new_tag" | LC_ALL=C command sort -V | command tail -n 1) != $new_tag ]]
   then
      print -u2 -r -- "ztag: $new_tag must be greater than the highest existing tag ($highest)"
      return 1
   fi

   print -r -- "ztag: creating $new_tag on main (previous highest: $highest)"

   if ! command git tag -a "$new_tag" -m "$comment"; then
      print -u2 -r -- "ztag: failed to create local tag $new_tag"
      return 1
   fi

   if ! command git push origin "$new_tag"; then
      print -u2 -r -- "ztag: push failed; local tag $new_tag remains available"
      return 1
   fi

   print -r -- "ztag: pushed $new_tag to origin"
}
