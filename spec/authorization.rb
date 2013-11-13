require 'roadforest/authorization'

describe RoadForest::Authorization do
  subject :manager do
    RoadForest::Authorization::Manager.new.tap do |manager|
      manager.authenticator.add_account("user","secret","")
    end
  end

  describe "default setup" do
    let :requires_admin do
      manager.build_grants do |grants|
        grants.add(:admin)
      end
    end

    it "should refuse an unauthenticated user" do
      manager.authorization(nil, requires_admin).should == :refused
    end

    it "should grant an authenticated user" do
      manager.authorization("Basic #{Base64.encode64("user:secret")}", requires_admin).should == :granted
    end

    it "should refuse a garbage authentication header" do
      manager.authorization("some garbage here", requires_admin).should == :refused
    end

    it "should construct a valid challenge header" do
      manager.challenge(:realm => "This test here").should == 'Basic realm="This test here"'

    end
  end
end
