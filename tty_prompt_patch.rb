# https://github.com/Thomascountz/tty-prompt/pull/1/files
module MultiListPatch
  def keyenter(*)
    valid = true
    valid = @min <= @selected.size if @min
    valid &= @selected.size <= @max if @max

    super if valid
  end
end

TTY::Prompt::MultiList.include(MultiListPatch)
