require 'spec_helper'

describe RestPack::Serializer::Paging do
  before(:each) do
    @album1 = FactoryGirl.create(:album_with_songs, song_count: 11)
    @album2 = FactoryGirl.create(:album_with_songs, song_count: 7)
  end

  context "#page" do
    let(:page) { MyApp::SongSerializer.page(params) }
    let(:params) { { } }

    context "with defaults" do
      it "page defaults to 1" do
        page[:meta][:songs][:page].should == 1
      end
      it "page_size defaults to 10" do
        page[:meta][:songs][:page_size].should == 10
      end
      it "includes valid paging meta data" do
        page[:meta][:songs][:count].should == 18
        page[:meta][:songs][:page_count].should == 2
        page[:meta][:songs][:previous_page].should == nil
        page[:meta][:songs][:previous_href].should == nil
        page[:meta][:songs][:next_page].should == 2
        page[:meta][:songs][:next_href].should == '/songs.json?page=2'
      end
      it "includes links" do
        page[:links].should == {
          'songs.album' => { :href => "/albums/{songs.album}.json", :type => :albums },
          'songs.artist' => { :href => "/artists/{songs.artist}.json", :type => :artists }
        }
      end
    end

    context "with custom page size" do
      let(:params) { { page_size: '3' } }
      it "returns custom page sizes" do
        page[:meta][:songs][:page_size].should == 3
        page[:meta][:songs][:page_count].should == 6
      end
      it "includes the custom page size in the page hrefs" do
        page[:meta][:songs][:next_page].should == 2
        page[:meta][:songs][:next_href].should == '/songs.json?page=2&page_size=3'
      end
    end

    context "with custom filter" do
      context "valid :title" do
        let(:params) { { title: @album1.songs[0].title } }
        it "returns the album" do
          page[:meta][:songs][:count].should == 1
        end
      end

      context "invalid :title" do
        let(:params) { { title: "this doesn't exist" } }
        it "returns the album" do
          page[:meta][:songs][:count].should == 0
        end
      end
    end

    it "serializes results" do
      first = MyApp::Song.first
      page[:songs].first.should == {
        id: first.id.to_s,
        title: first.title,
        album_id: first.album_id,
        links: {
          album: first.album_id.to_s,
          artist: first.artist_id.to_s
        }
      }
    end

    context "first page" do
      let(:params) { { page: '1' } }

      it "returns first page" do
        page[:meta][:songs][:page].should == 1
        page[:meta][:songs][:page_size].should == 10
        page[:meta][:songs][:previous_page].should == nil
        page[:meta][:songs][:next_page].should == 2
      end
    end

    context "second page" do
      let(:params) { { page: '2' } }

      it "returns second page" do
        page[:songs].length.should == 8
        page[:meta][:songs][:page].should == 2
        page[:meta][:songs][:previous_page].should == 1
        page[:meta][:songs][:next_page].should == nil
        page[:meta][:songs][:previous_href].should == '/songs.json'
      end
    end

    context "when sideloading" do
      let(:params) { { includes: 'albums' } }

      it "includes side-loaded models" do
        page[:albums].should_not == nil
      end

      it "includes the side-loads in the main meta data" do
        page[:meta][:songs][:includes].should == [:albums]
      end

      it "includes the side-loads in page hrefs" do
        page[:meta][:songs][:next_href].should == '/songs.json?page=2&includes=albums'
      end

      context "with includes as comma delimited string" do
        let(:params) { { includes: "albums,artists" } }
        it "includes side-loaded models" do
          page[:albums].should_not == nil
          page[:artists].should_not == nil
        end

        it "includes the side-loads in page hrefs" do
          page[:meta][:songs][:next_href].should == '/songs.json?page=2&includes=albums,artists'
        end

        it "includes links" do
          page[:links]['songs.album'].should_not == nil
          page[:links]['songs.artist'].should_not == nil
          page[:links]['albums.songs'].should_not == nil
          page[:links]['albums.artist'].should_not == nil
          page[:links]['artists.songs'].should_not == nil
          page[:links]['artists.albums'].should_not == nil
        end
      end
    end

    context "when filtering" do
      context "with no filters" do
        let(:params) { {} }

        it "returns a page of all data" do
          page[:meta][:songs][:count].should == 18
        end
      end

      context "with :album_id filter" do
        let(:params) { { album_id: @album1.id.to_s } }

        it "returns a page with songs from album1" do
          page[:meta][:songs][:count].should == @album1.songs.length
        end

        it "includes the filter in page hrefs" do
          page[:meta][:songs][:next_href].should == "/songs.json?page=2&album_id=#{@album1.id}"
        end
      end
    end

    context "with custom scope" do
      before do
        FactoryGirl.create(:album, year: 1930)
        FactoryGirl.create(:album, year: 1948)
      end
      let(:page) { MyApp::AlbumSerializer.page(params, scope) }
      let(:scope) { MyApp::Album.classic }

      it "returns a page of scoped data" do
        page[:meta][:albums][:count].should == 2
      end
    end
  end

  context "#page_with_options" do
    let(:page) { MyApp::SongSerializer.page_with_options(options) }
    let(:params) { {} }
    let(:options) { RestPack::Serializer::Options.new(MyApp::SongSerializer, params) }

    context "with defaults" do
      it "includes valid paging meta data" do
        page[:meta][:songs][:count].should == 18
        page[:meta][:songs][:page_count].should == 2
        page[:meta][:songs][:previous_page].should == nil
        page[:meta][:songs][:next_page].should == 2
      end
    end

    context "with custom page size" do
      let(:params) { { page_size: '3' } }
      it "returns custom page sizes" do
        page[:meta][:songs][:page_size].should == 3
        page[:meta][:songs][:page_count].should == 6
      end
    end
  end

  context "paging with paged side-load" do
    let(:page) { MyApp::AlbumSerializer.page_with_options(options) }
    let(:options) { RestPack::Serializer::Options.new(MyApp::AlbumSerializer, { includes: 'songs' }) }

    it "includes side-loaded paging data in meta data" do
      page[:meta][:albums].should_not == nil
      page[:meta][:albums][:page].should == 1
      page[:meta][:songs].should_not == nil
      page[:meta][:songs][:page].should == 1
    end
  end

  context "paging with two paged side-loads" do
    let(:page) { MyApp::ArtistSerializer.page_with_options(options) }
    let(:options) { RestPack::Serializer::Options.new(MyApp::ArtistSerializer, { includes: 'albums,songs' }) }

    it "includes side-loaded paging data in meta data" do
      page[:meta][:albums].should_not == nil
      page[:meta][:albums][:page].should == 1
      page[:meta][:songs].should_not == nil
      page[:meta][:songs][:page].should == 1
    end
  end
end
