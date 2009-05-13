require File.dirname(__FILE__) + '/../../../spec_helper'

def regex_for_url_with_params(url, *params)
  regex = '^' + url.gsub('/','\/').gsub('.','\.')
  regex += '\?' unless params.empty?

  unless params.empty?
    param_possibilities = params.join('|')
    regex += params.inject([]) { |list, param| list << "(#{param_possibilities})" }.join('&')
  end
  regex += '$'
  Regexp.new(regex)
end

class TestHarness
  extend CurbFu::Request::Base
end

describe CurbFu::Request::Base do
  describe "build_url" do
    it "should return a string if a string parameter is given" do
      TestHarness.build_url("http://www.cliffsofinsanity.com").should == "http://www.cliffsofinsanity.com"
    end
    it "should return a built url with just a hostname if only the hostname is given" do
      TestHarness.build_url(:host => "poisonedwine.com").should == "http://poisonedwine.com"
    end
    it "should return a built url with hostname and port if port is also given" do
      TestHarness.build_url(:host => "www2.giantthrowingrocks.com", :port => 8080).
        should == "http://www2.giantthrowingrocks.com:8080"
    end
    it "should return a built url with hostname, port, and path if all are given" do
      TestHarness.build_url(:host => "spookygiantburningmonk.org", :port => 3000, :path => '/standing/in/a/wheelbarrow.aspx').
        should == "http://spookygiantburningmonk.org:3000/standing/in/a/wheelbarrow.aspx"
    end
    it 'should append a query string if a query params hash is given' do
      TestHarness.build_url('http://navyseals.mil', :swim_speed => '2knots').
        should == 'http://navyseals.mil?swim_speed=2knots'
    end
    it 'should append a query string if a query string is given' do
      TestHarness.build_url('http://chocolatecheese.com','?nuts=true').
        should == 'http://chocolatecheese.com?nuts=true'
    end
  end

  describe "build_query_string" do
    it 'should build a query string' do
      params = { 'foo' => 'bar', 'rat' => 'race' }
      url = TestHarness.build_query_string(params)
      url.should =~ regex_for_url_with_params('', 'foo=bar', 'rat=race')
    end
    it 'should return an empty string if params is an empty hash' do
      TestHarness.build_query_string({}).should == ''
    end
  end

  describe "get" do
    it "should get the google" do
      TestHarness.get("http://www.google.com").should be_a_kind_of(CurbFu::Response::OK)
    end
    it "should return a status code" do
      TestHarness.get("http://www.google.com").status.should == 200
    end
    it "should return a body" do
      TestHarness.get("http://www.google.com").body.should =~ /html/
    end
    it "should return a 404 code correctly" do
      TestHarness.get("http://www.google.com/ponies_and_pirates").status.should == 404
      TestHarness.get("http://www.google.com/ponies_and_pirates").should be_a_kind_of(CurbFu::Response::NotFound)
    end
    it "should append query parameters" do
      @mock_curb = mock(Curl::Easy, :headers= => nil, :headers => {}, :header_str => "", :response_code => 200, :body_str => 'yeeeah', :timeout= => nil, :http_get => nil)
      Curl::Easy.should_receive(:new).with(regex_for_url_with_params('http://www.google.com', 'search=MSU vs UNC', 'limit=200')).and_return(@mock_curb)
      TestHarness.get('http://www.google.com', { :search => 'MSU vs UNC', :limit => 200 })
    end

    describe "with_hash" do
      it "should get google from {:host => \"www.google.com\", :port => 80}" do
        TestHarness.get({:host => "www.google.com", :port => 80}).should be_a_kind_of(CurbFu::Response::OK)
      end

      it "should set authorization username and password if provided" do
        TestHarness.get({:host => "control.greenviewdata.com", :port => 80, :username => "archiver", :password => "test"}).
          should be_a_kind_of(CurbFu::Response::OK)
      end
      it "should append parameters to the url" do
        @mock_curb = mock(Curl::Easy, :headers= => nil, :headers => {}, :header_str => "", :response_code => 200, :body_str => 'yeeeah', :timeout= => nil, :http_get => nil)
        Curl::Easy.should_receive(:new).with(regex_for_url_with_params('http://www.google.com', 'search=MSU vs UNC', 'limit=200')).and_return(@mock_curb)
        TestHarness.get({ :host => 'www.google.com' }, { :search => 'MSU vs UNC', :limit => 200 })
      end
    end
  end

  describe "post" do
    before(:each) do
      @mock_curb = mock(Curl::Easy, :headers= => nil, :headers => {}, :header_str => "", :response_code => 200, :body_str => 'yeeeah', :timeout= => nil)
      Curl::Easy.stub!(:new).and_return(@mock_curb)
    end

    it "should send each parameter to Curb#http_post" do
      @mock_q = Curl::PostField.content('q','derek')
      @mock_r = Curl::PostField.content('r','matt')
      Curl::PostField.stub!(:content).with('q','derek').and_return(@mock_q)
      Curl::PostField.stub!(:content).with('r','matt').and_return(@mock_r)

      @mock_curb.should_receive(:http_post).with(@mock_q,@mock_r)

      response = TestHarness.post(
        {:host => "google.com", :port => 80, :path => "/search"},
        { 'q' => 'derek', 'r' => 'matt' })
    end

    it "should handle params that contain arrays" do
      @mock_q = Curl::PostField.content('q','derek,matt')
      Curl::PostField.stub!(:content).with('q','derek,matt').and_return(@mock_q)

      @mock_curb.should_receive(:http_post).with(@mock_q)

      response = TestHarness.post(
        {:host => "google.com", :port => 80, :path => "/search"},
        { 'q' => ['derek','matt'] })
    end

    it "should handle params that contain any non-Array or non-String data" do
      @mock_q = Curl::PostField.content('q','1')
      Curl::PostField.stub!(:content).with('q','1').and_return(@mock_q)

      @mock_curb.should_receive(:http_post).with(@mock_q)

      response = TestHarness.post(
        {:host => "google.com", :port => 80, :path => "/search"},
        { 'q' => 1 })
    end
  end

  describe "put" do
    before(:each) do
      @mock_curb = mock(Curl::Easy, :headers= => nil, :headers => {}, :header_str => "", :response_code => 200, :body_str => 'yeeeah', :timeout= => nil)
      Curl::Easy.stub!(:new).and_return(@mock_curb)
    end

    it "should send each parameter to Curb#http_post" do
      @mock_curb.should_receive(:http_put).with("q=derek","r=matt")

      response = TestHarness.put(
        {:host => "google.com", :port => 80, :path => "/search"},
        { 'q' => 'derek', 'r' => 'matt' })
    end

    it "should handle params that contain arrays" do
      @mock_curb.should_receive(:http_put).with("q=derek,matt")

      response = TestHarness.put(
        {:host => "google.com", :port => 80, :path => "/search"},
        { 'q' => ['derek','matt'] })
    end

    it "should handle params that contain any non-Array or non-String data" do
      @mock_curb.should_receive(:http_put).with("q=1")

      response = TestHarness.put(
        {:host => "google.com", :port => 80, :path => "/search"},
        { 'q' => 1 })
    end
  end
end