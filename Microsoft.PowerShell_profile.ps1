function syntax($cmd) { Get-Command $cmd -Syntax }   # or (Get-Command $cmd).Definition
function parameter($cmd, $parameter) { Get-Help $cmd -Parameter $parameter }

# or these could be for the common-module

# git init
# git add Microsoft.PowerShell_profile.ps1
# git status
# git commit -m "adding files"
# git remote add origin https://github.com/roysubs/psprofile.git
# git pull origin master --allow-unrelated-histories
    # Had to do this to force the merge to happen.
# git push -u origin master
# git clone https://github.com/roysubs/psprofile.git
