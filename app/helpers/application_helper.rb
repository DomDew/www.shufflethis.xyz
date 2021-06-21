module ApplicationHelper
  def reload_flash
    page.replace 'flash_messages', partial: 'layouts/flash'
  end
end
