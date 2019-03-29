require 'json'

module Danger
  class DangerKtlint < Plugin
    # TODO: Lint all files if `filtering: false`
    attr_accessor :filtering

    # Run ktlint task using command line interface
    # Will fail if `ktlint` is not installed
    # Skip lint task if files changed are empty
    # @return [void]
    # def lint(inline_mode: false)
    def lint(inline_mode: false)
      unless ktlint_exists?
        fail("Couldn't find ktlint command. Install first.")
        return
      end

      targets = target_files(git.added_files + git.modified_files)
      return if targets.empty?

      results = JSON.parse(`ktlint #{targets.join(' ')} --reporter=json --relative`)
      return if results.empty?

      if inline_mode
        send_inline_comments(results)
      else
        send_markdown_comment(results)
      end
    end

    # Comment to a PR by ktlint result json
    #
    # // Sample ktlint result
    # [
    #   {
    #     "file": "app/src/main/java/com/mataku/Model.kt",
    # 		"errors": [
    # 			{
    # 				"line": 46,
    # 				"column": 1,
    # 				"message": "Unexpected blank line(s) before \"}\"",
    # 				"rule": "no-blank-line-before-rbrace"
    # 			}
    # 		]
    # 	}
    # ]
    def send_markdown_comment(results)
      results.each {|result|
        result['errors'].each {|error|
          file = "#{result['file']}#L#{error['line']}"
          message = "#{bitbucket.html_link(file)}: #{error['message']}"
          fail(message)
        }
      }
    end

    def send_inline_comments(results)
      results.each do |result|
        result['errors'].each do |error|
          file = result['file']
          message = error['message']
          line = error['line']
          fail(message, file: file, line: line)
        end
      end
    end

    def target_files(changed_files)
      changed_files.select do |file|
        file.end_with?('.kt')
      end
    end

    private

    def ktlint_exists?
      system 'which ktlint > /dev/null 2>&1'
    end
  end
end
