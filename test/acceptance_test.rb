require_relative 'test_helper'

describe Flow::App do
  it "has a working front page" do
    visit '/'
    page.must_have_content "TestFlow"
  end

  it "has a working front page for a logged in user" do
    user = User.create username: 'test', email: 'test@example.com', fullname: 'Test Test'
    page.set_rack_session logged_in: user.id
    page.visit '/'
    save_and_open_page
    page.get_rack_session_key('logged_in').must_equal user.id
    p page.get_rack_session
  end
end
