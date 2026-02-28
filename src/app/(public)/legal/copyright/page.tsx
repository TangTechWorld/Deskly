export default function CopyrightPage() {
  return (
    <main className="min-h-screen flex items-center justify-center bg-gray-50 py-8 px-2">
      <div className="w-full max-w-3xl bg-white rounded-xl shadow-lg p-8 md:p-12 border border-gray-200">
        <div className="prose prose-blue max-w-none prose-p:my-2 prose-ul:my-2 prose-li:my-1 prose-hr:my-4">
          <h1>Copyright & Infringement Policy</h1>
          <p>
            <em>Last Updated: February 17, 2026</em>
          </p>
          <p>Deskly respects intellectual property rights.</p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">Submitting a Notice</h2>
          <p>If you believe content infringes your copyright, include:</p>
          <ul>
            <li>Your name and contact information</li>
            <li>Identification of the copyrighted work</li>
            <li>Identification of the allegedly infringing material (URL)</li>
            <li>A good faith statement that use is unauthorized</li>
            <li>A statement of accuracy</li>
            <li>Your electronic or physical signature</li>
          </ul>
          <p>Email notices to: support@deskly.app</p>
          <hr className="border-gray-100" />
          <h2 className="text-blue-600">Counter-Notification</h2>
          <p>If content was removed in error, include:</p>
          <ul>
            <li>Your contact information</li>
            <li>Identification of removed content</li>
            <li>A statement explaining the mistake</li>
            <li>Your signature</li>
          </ul>
          <p>
            We may remove content and terminate repeat infringers at our
            discretion. We do not proactively monitor user-uploaded content.
          </p>
          <p>Email notices to: support@deskly.app</p>
        </div>
      </div>
    </main>
  );
}
