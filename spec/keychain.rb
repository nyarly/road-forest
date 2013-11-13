require 'roadforest/http/keychain'

describe RoadForest::HTTP::Keychain do
  let :expected_header do
    "Basic dXNlcjpzZWNyZXRl"
  end

  let :username do
    "user"
  end

  let :password do
    "secrete"
  end

  describe "Basic scheme regex" do
    let :regex do
      RoadForest::HTTP::Keychain::BASIC_SCHEME
    end

    it "should match with single-quote realm" do
      match = regex.match "Basic realm='test'"
      match[:realm].should == "test"
    end

    it "should not match without realm" do
      match = regex.match 'Basic'
      match.should be_nil
    end

    it "should match with double-quote realm" do
      match = regex.match 'Basic realm="test"'
      match[:realm].should == "test"
    end

    it "should not match with mismatched-quote realm" do
      match = regex.match "Basic realm=\"test'"
      match.should be_nil
    end
  end

  describe "#preemptive_response" do
    subject :keychain do
      RoadForest::HTTP::Keychain.new.tap do |chain|
        chain.add("http://example.com/test/", username, password)
      end
    end

    it "should return matching creds" do
      creds = keychain.preemptive_response("http://example.com/test/under/here/")
      creds.should == expected_header
    end

    it "should not return creds from outside protection" do
      creds = keychain.preemptive_response("http://example.com/")
      creds.should be_nil
    end
  end

  describe "#challenge_response" do
    subject :keychain do
      RoadForest::HTTP::Keychain.new.tap do |chain|
        chain.add("http://example.com/test/", username, password, "test")
      end
    end

    it "should return matching creds" do
      creds = keychain.challenge_response("http://example.com/", "Basic realm='test'")
      creds.should == expected_header
    end

    it "should not return covering creds" do
      creds = keychain.challenge_response("http://example.com/test/under/here/", "Basic realm='other'")
      creds.should be_nil
    end

    it "should not return non-matching creds" do
      creds = keychain.challenge_response("http://example.com/", "Basic realm='other'")
      creds.should be_nil
    end
  end
end
