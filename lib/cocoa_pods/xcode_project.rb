framework 'Foundation'

module Pod
  class XcodeProject
    TEMPLATES_DIR = Pathname.new(File.expand_path('../../../xcode-project-templates', __FILE__))

    # TODO see if we really need different templates for iOS and OS X
    def self.static_library
      new TEMPLATES_DIR + 'cocoa-touch-static-library'
    end

    def initialize(template_dir)
      @template_dir = template_dir
      file = template_dir + template_file
      @template = NSMutableDictionary.dictionaryWithContentsOfFile(file.to_s)
    end

    def template_file
      'Pods.xcodeproj/project.pbxproj'
    end

    def add_source_file(file)
      file_ref_uuid = add_file_reference(file, 'SOURCE_ROOT')
      add_file_to_group(file_ref_uuid, 'Pods')
      if file.extname == '.h'
        build_file_uuid = add_build_file(file_ref_uuid, "settings" => { "ATTRIBUTES" => ["Public"] })
        add_file_to_list('PBXHeadersBuildPhase', build_file_uuid)
      else
        build_file_uuid = add_build_file(file_ref_uuid)
        add_file_to_list('PBXSourcesBuildPhase', build_file_uuid)
      end
    end

    def add_framework(path)
      file_ref_uuid = add_file_reference(path, 'SDKROOT')
      add_file_to_group(file_ref_uuid, 'Frameworks')
      build_file_uuid = add_build_file(file_ref_uuid)
      add_file_to_list('PBXFrameworksBuildPhase', build_file_uuid)
    end

    def add_header_search_path(path)
      objects_by_isa('XCBuildConfiguration').each do |_, object|
        (object['buildSettings']['HEADER_SEARCH_PATHS'] ||= []) << path
      end
    end

    def to_hash
      @template
    end

    def create_in(pods_root)
      @template_dir.children.each do |child|
        FileUtils.cp_r(child, pods_root + child.relative_path_from(@template_dir))
      end
      pbxproj = pods_root + template_file
      @template.writeToFile(pbxproj.to_s, atomically:true)
    end

    private

    def add_object(object)
      uuid = generate_uuid
      objects[uuid] = object
      uuid
    end

    def add_file_reference(path, source_tree)
      add_object({
        "name" => path.basename.to_s,
        "isa" => "PBXFileReference",
        "sourceTree" => source_tree,
        "path" => path.to_s,
      })
    end

    def add_build_file(file_ref_uuid, extra = {})
      add_object(extra.merge({
        "isa" => "PBXBuildFile",
        "fileRef" => file_ref_uuid
      }))
    end

    def add_file_to_list(isa, build_file_uuid)
      object_uuid, object = objects_by_isa(isa).first
      object['files'] << build_file_uuid
    end

    def add_file_to_group(file_ref_uuid, name)
      object_uuid, object = objects.find do |_, object|
        object['isa'] == 'PBXGroup' && object['name'] == name
      end
      object['children'] << file_ref_uuid
    end

    def objects
      @template['objects']
    end

    def objects_by_isa(isa)
      objects.select { |_, object| object['isa'] == isa }
    end

    def generate_uuid
      _uuid = CFUUIDCreate(nil)
      uuid = CFUUIDCreateString(nil, _uuid)
      CFRelease(_uuid)
      CFMakeCollectable(uuid)
      # Xcode's version is actually shorter, not worrying about collisions too much right now.
      uuid.gsub('-', '')[0..23]
    end

    public

    def pretty_print
      puts `ruby -r pp -e 'pp(#{@template.inspect})'`
    end
  end
end