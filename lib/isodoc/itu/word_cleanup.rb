module IsoDoc
  module ITU
    class WordConvert < IsoDoc::WordConvert
      def word_preface_cleanup(docxml)
        docxml.xpath("//h1[@class = 'AbstractTitle'] | "\
                     "//h1[@class = 'IntroTitle']").each do |h2|
          h2.name = "p"
          h2["class"] = "h1Preface"
        end
      end

      def word_term_cleanup(docxml)
      end

      def word_cleanup(docxml)
        word_footnote_cleanup(docxml)
        word_title_cleanup(docxml)
        word_preface_cleanup(docxml)
        word_term_cleanup(docxml)
        word_history_cleanup(docxml)
        authority_hdr_cleanup(docxml)
        table_list_style(docxml)
        super
        docxml
      end

      def word_footnote_cleanup(docxml)
        docxml.xpath("//aside").each do |a|
          a.first_element_child.children.first.previous =
            '<span style="mso-tab-count:1"/>'
        end
      end

      def word_title_cleanup(docxml)
        docxml.xpath("//p[@class = 'annex_obligation']").each do |h|
          h&.next_element&.name == "p" or next
          h.next_element["class"] ||= "Normalaftertitle"
        end
        docxml.xpath("//p[@class = 'FigureTitle']").each do |h|
          h&.parent&.next_element&.name == "p" or next
          h.parent.next_element["class"] ||= "Normalaftertitle"
        end
      end

      def word_history_cleanup(docxml)
        docxml.xpath("//div[@id='_history']//table").each do |t|
          t["class"] = "MsoNormalTable"
          t.xpath(".//td").each { |td| td["style"] = nil }
        end
      end

      def word_preface(docxml)
        super
        abstractbox = docxml.at("//div[@id='abstractbox']")
        historybox = docxml.at("//div[@id='historybox']")
        sourcebox = docxml.at("//div[@id='sourcebox']")
        keywordsbox = docxml.at("//div[@id='keywordsbox']")
        changelogbox = docxml.at("//div[@id='change_logbox']")
        abstract = docxml.at("//div[@class = 'Abstract']")
        history = docxml.at("//div[@class = 'history']")
        source = docxml.at("//div[@class = 'source']")
        keywords = docxml.at("//div[@class = 'Keyword']")
        changelog = docxml.at("//div[@id = 'change_log']")
        abstract.parent = abstractbox if abstract && abstractbox
        history.parent = historybox if history && historybox
        source.parent = sourcebox if source && sourcebox
        keywords.parent = keywordsbox if keywords && keywordsbox
        changelog.parent = changelogbox if changelog && changelogbox
      end

      def toWord(result, filename, dir, header)
        result = populate_template(result, :word)
        result = from_xhtml(word_cleanup(to_xhtml(result)))
        unless @landscapestyle.nil? || @landscapestyle.empty?
          @wordstylesheet&.open
          @wordstylesheet&.write(@landscapestyle)
          @wordstylesheet&.close
        end
        Html2Doc.process(
          result, filename: filename, 
          stylesheet: @wordstylesheet&.path,
          header_file: header&.path, dir: dir,
          asciimathdelims: [@openmathdelim, @closemathdelim],
          liststyles: { ul: @ulstyle, ol: @olstyle, steps: "l4" })
        header&.unlink
        @wordstylesheet&.unlink
      end

      def authority_hdr_cleanup(docxml)
        docxml&.xpath("//div[@id = 'draft-warning']").each do |d|
          d.xpath(".//h1 | .//h2").each do |p|
            p.name = "p"
            p["class"] = "draftwarningHdr"
          end
        end
        %w(copyright license legal).each do |t|
          docxml&.xpath("//div[@class = 'boilerplate-#{t}']").each do |d|
            p = d&.at("./descendant::h1[2]") and
              p.previous = "<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p>"
            d.xpath(".//h1 | .//h2").each do |p|
              p.name = "p"
              p["class"] = "boilerplateHdr"
            end
          end
        end
      end

      def authority_cleanup(docxml)
        dest = docxml.at("//div[@class = 'draft-warning']")
        auth = docxml.at("//div[@id = 'draft-warning']")
        dest and auth and dest.replace(auth.remove)
        %w(copyright license legal).each do |t|
          dest = docxml.at("//div[@id = 'boilerplate-#{t}-destination']")
          auth = docxml.at("//div[@class = 'boilerplate-#{t}']")
          next unless auth && dest
          t == "copyright" and p = auth&.at(".//p") and
            p["class"] = "boilerplateHdr"
          auth&.xpath(".//p[not(@class)]")&.each_with_index do |p, i|
            p["class"] = "boilerplate"
            #i == 0 && t == "copyright" and p["style"] = "text-align:center;"
          end
          t == "copyright" or
            auth << "<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p>" 
          dest.replace(auth.remove)
        end
      end

      TOPLIST = "[not(ancestor::ul) and not(ancestor::ol)]".freeze

      def table_list_style(xml)
        xml.xpath("//table//ul#{TOPLIST} | //table//ol#{TOPLIST}").each do |t|
          table_list_style1(t, 1)
        end
      end

      def table_list_style1(t, num)
        (t.xpath(".//li") - t.xpath(".//ol//li | .//ul//li")).each do |t1|
          indent_list(t1, num)
          t1.xpath("./div | ./p").each { |p| indent_list(p, num) }
          (t1.xpath(".//ul") - t1.xpath(".//ul//ul | .//ol//ul")).each do |t2|
            table_list_style1(t2, num + 1)
          end
          (t1.xpath(".//ol") - t1.xpath(".//ul//ol | .//ol//ol")).each do |t2|
            table_list_style1(t2, num + 1)
          end
        end
      end

      def indent_list(li, num)
        li["style"] = (li["style"] ? li["style"] + ";" : "")
        li["style"] += "margin-left: #{num * 0.5}cm;text-indent: -0.5cm;"
      end
    end
  end
end
