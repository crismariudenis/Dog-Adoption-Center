import { useEffect, useRef, useState } from 'react'
import { api } from '../api/api'
import { useAuth } from '../contexts/AuthContext'

const MOCK_DOGS = [
  { id: 1, name: 'Buddy', breed: 'Golden Retriever', age: '2 years', status: 'Available', breedSlug: 'retriever/golden' },
  { id: 2, name: 'Max', breed: 'Doberman', age: '3 years', status: 'Available', breedSlug: 'doberman' },
  { id: 3, name: 'Bella', breed: 'Labrador', age: '1 year', status: 'Pending', breedSlug: 'labrador' },
  { id: 4, name: 'Charlie', breed: 'Beagle', age: '4 years', status: 'Available', breedSlug: 'beagle' },
  { id: 5, name: 'Luna', breed: 'Husky', age: '2 years', status: 'Available', breedSlug: 'husky' },
  { id: 6, name: 'Rocky', breed: 'Bulldog', age: '5 years', status: 'Adopted', breedSlug: 'bulldog/english' },
]

const statusStyle = {
  Available: 'bg-green-100 text-green-700',
  Pending: 'bg-yellow-100 text-yellow-700',
  Adopted: 'bg-gray-100 text-gray-500',
}

function AdoptModal({ dog, onClose }) {
  const { user, token } = useAuth()
  const [form, setForm] = useState({
    message: '',
    requiresLandlordConsent: false,
    documents: [
      { documentType: 'GovernmentId', file: null },
      { documentType: 'ProofOfResidence', file: null },
    ],
  })
  const [submitting, setSubmitting] = useState(false)
  const [success, setSuccess] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')
  const [validation, setValidation] = useState(null)
  const [extraction, setExtraction] = useState(null)

  const toDocumentPayload = (document) => {
    if (!document.file) {
      return null
    }

    return {
      documentType: document.documentType,
      fileName: document.file.name,
      contentType: document.file.type || 'application/octet-stream',
      sizeBytes: document.file.size,
    }
  }

  const updateDocument = (index, field, value) => {
    setForm(current => {
      const documents = [...current.documents]
      documents[index] = { ...documents[index], [field]: value }
      return { ...current, documents }
    })
  }

  const addLandlordConsent = () => {
    setForm(current => {
      if (current.documents.some(document => document.documentType === 'LandlordConsent')) {
        return current
      }

      return {
        ...current,
        requiresLandlordConsent: true,
        documents: [
          ...current.documents,
          { documentType: 'LandlordConsent', file: null },
        ],
      }
    })
  }

  const validateApplication = async () => {
    setErrorMsg('')
    setValidation(null)
    setExtraction(null)

    try {
      const userId = getUserId(token)
      const result = await api.validateApplication({
        petId: `00000000-0000-0000-0000-00000000000${dog.id}`,
        userId,
        applicantName: user?.username ?? user?.email ?? 'Anonymous',
        applicantEmail: user?.email ?? 'anonymous@example.com',
        justification: form.message,
        requiresLandlordConsent: form.requiresLandlordConsent,
        documents: form.documents.map(toDocumentPayload).filter(Boolean),
      }, token)

      setValidation(result)
      if (!result.isValid) {
        setErrorMsg(result.errors.join(' '))
        return
      }

      const idDocument = form.documents.find(document => document.documentType === 'GovernmentId')?.file
      const bankStatement = form.documents.find(document => document.documentType === 'ProofOfResidence')?.file

      if (!idDocument || !bankStatement) {
        setErrorMsg('Upload both GovernmentId and ProofOfResidence files to run extraction.')
        return
      }

      const extractionResult = await api.scanDocuments(
        idDocument,
        bankStatement,
        user?.username ?? user?.email ?? '',
        token)

      setExtraction(extractionResult)
    } catch (err) {
      setErrorMsg(err?.message || 'Validation failed. Check the document fields and try again.')
      console.error(err)
    }
  }

  const getUserId = (authToken) => {
    let userId = '00000000-0000-0000-0000-000000000002'
    if (authToken) {
      try {
        const payload = JSON.parse(atob(authToken.split('.')[1]))
        if (payload.id) userId = payload.id
      } catch (e) {}
    }
    return userId
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setSubmitting(true)
    setErrorMsg('')

    const userId = getUserId(token)

    try {
      const validationResult = validation ?? await api.validateApplication({
        petId: `00000000-0000-0000-0000-00000000000${dog.id}`,
        userId,
        applicantName: user?.username ?? user?.email ?? 'Anonymous',
        applicantEmail: user?.email ?? 'anonymous@example.com',
        justification: form.message,
        requiresLandlordConsent: form.requiresLandlordConsent,
        documents: form.documents.map(toDocumentPayload).filter(Boolean),
      }, token)

      if (!validationResult.isValid) {
        setValidation(validationResult)
        setErrorMsg(validationResult.errors.join(' '))
        return
      }

      await api.submitApplication({
        petId: `00000000-0000-0000-0000-00000000000${dog.id}`,
        userId: userId,
        applicantName: user?.username ?? user?.email ?? 'Anonymous',
        applicantEmail: user?.email ?? 'anonymous@example.com',
        justification: form.message,
        requiresLandlordConsent: form.requiresLandlordConsent,
        documents: form.documents.map(toDocumentPayload).filter(Boolean),
      }, token)

      api.trackEvent({
        petId: '00000000-0000-0000-0000-00000000000' + dog.id,
        userId: userId,
        shelterId: '00000000-0000-0000-0000-000000000001',
        eventType: 'application.submitted',
        occurredAt: new Date().toISOString(),
        metadata: { petName: dog.name, applicantName: user?.username ?? '' },
      }).catch(() => {})

      setSuccess(true)
    } catch (err) {
      setErrorMsg('Failed to submit application. Please try again.')
      console.error(err)
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/40 flex items-start sm:items-center justify-center z-50 px-4 py-6 overflow-y-auto">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md p-6 max-h-[90vh] overflow-y-auto">
        {success ? (
          <div className="text-center py-6">
            <div className="text-5xl mb-4">🐾</div>
            <h2 className="text-xl font-bold text-amber-800 mb-2">Application Submitted!</h2>
            <p className="text-gray-500 text-sm mb-6">
              We'll be in touch about <strong>{dog.name}</strong> soon.
            </p>
            <button
              onClick={onClose}
              className="bg-amber-700 hover:bg-amber-600 text-white font-semibold px-6 py-2 rounded-lg transition"
            >
              Close
            </button>
          </div>
        ) : (
          <>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-amber-800">Adopt {dog.name}</h2>
              <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-xl leading-none">&times;</button>
            </div>
            <form onSubmit={handleSubmit} className="space-y-4">
              <p className="text-sm text-gray-500">
                Applying as <span className="font-medium text-gray-700">{user?.username ?? user?.email}</span>
              </p>
              {errorMsg && <p className="text-red-500 text-sm font-semibold">{errorMsg}</p>}
              {validation && (
                <div className={`rounded-lg p-3 text-sm ${validation.isValid ? 'bg-green-50 text-green-800' : 'bg-red-50 text-red-800'}`}>
                  <p className="font-semibold mb-1">{validation.isValid ? 'Validation passed locally.' : 'Validation failed locally.'}</p>
                  {!validation.isValid && (
                    <ul className="list-disc pl-5 space-y-1">
                      {validation.errors.map((item) => (
                        <li key={item}>{item}</li>
                      ))}
                    </ul>
                  )}
                </div>
              )}
              {extraction && (
                <div className="rounded-lg p-3 text-sm bg-blue-50 text-blue-900 space-y-2">
                  <p className="font-semibold">Extracted document data</p>
                  <p><strong>ID Name:</strong> {extraction.extractedIdName || 'Not found'}</p>
                  {extraction.idImagePreviewBase64 && (
                    <img src={extraction.idImagePreviewBase64} alt="Extracted ID preview" className="w-40 h-auto rounded border border-blue-200" />
                  )}
                  <p><strong>Bank Balance:</strong> {extraction.extractedBankBalance != null ? `${extraction.extractedBankBalance} ${extraction.extractedBankCurrency || ''}` : 'Not found'}</p>
                  <p><strong>Bank Country:</strong> {extraction.extractedBankCountry || 'Not found'}</p>
                  {Array.isArray(extraction.warnings) && extraction.warnings.length > 0 && (
                    <ul className="list-disc pl-5">
                      {extraction.warnings.map((warning) => (
                        <li key={warning}>{warning}</li>
                      ))}
                    </ul>
                  )}
                </div>
              )}
              <div>
                <label className="block text-xs text-gray-500 mb-1">Why do you want to adopt {dog.name}?</label>
                <textarea
                  required
                  value={form.message}
                  onChange={e => setForm({ ...form, message: e.target.value })}
                  rows={3}
                  className="w-full border border-amber-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-amber-400 resize-none"
                  placeholder="Tell us a bit about yourself..."
                />
              </div>
              <div className="rounded-xl border border-amber-100 bg-amber-50/60 p-3 space-y-3">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-sm font-semibold text-amber-900">Document checklist</p>
                    <p className="text-xs text-amber-700">This is only validated locally and is not stored.</p>
                  </div>
                  <button
                    type="button"
                    onClick={addLandlordConsent}
                    className="text-xs font-semibold px-3 py-1.5 rounded-full bg-white border border-amber-200 text-amber-800 hover:bg-amber-100"
                  >
                    Add landlord consent
                  </button>
                </div>

                <label className="flex items-center gap-2 text-sm text-gray-700">
                  <input
                    type="checkbox"
                    checked={form.requiresLandlordConsent}
                    onChange={(e) => setForm(current => ({ ...current, requiresLandlordConsent: e.target.checked }))}
                  />
                  Requires landlord consent
                </label>

                {form.documents.map((document, index) => (
                  <div key={`${document.documentType}-${index}`} className="grid grid-cols-1 gap-2 rounded-lg bg-white p-3 border border-amber-100">
                    <div className="text-xs font-semibold text-amber-800">{document.documentType}</div>
                    <input
                      type="file"
                      accept=".pdf,.png,.jpg,.jpeg"
                      className="w-full border border-amber-200 rounded-lg px-3 py-2 text-sm bg-white"
                      onChange={(e) => updateDocument(index, 'file', e.target.files?.[0] ?? null)}
                    />
                    <p className="text-xs text-gray-500">
                      {document.file ? `Selected: ${document.file.name} (${document.file.type || 'unknown type'})` : 'No file selected'}
                    </p>
                  </div>
                ))}
              </div>
              <button
                type="button"
                onClick={validateApplication}
                className="w-full bg-white border border-amber-200 text-amber-800 font-semibold py-2 rounded-lg hover:bg-amber-50 transition"
              >
                Validate Documents
              </button>
              <button
                type="submit"
                disabled={submitting}
                className="w-full bg-amber-700 hover:bg-amber-600 disabled:bg-gray-300 text-white font-semibold py-2 rounded-lg transition"
              >
                {submitting ? 'Submitting...' : 'Submit Application'}
              </button>
            </form>
          </>
        )}
      </div>
    </div>
  )
}

export default function HomePage() {
  const dogsRef = useRef(null)
  const [selectedDog, setSelectedDog] = useState(null)
  const [dogImages, setDogImages] = useState({})

  const scrollToDogs = () => dogsRef.current?.scrollIntoView({ behavior: 'smooth' })

  useEffect(() => {
    MOCK_DOGS.forEach(dog => {
      fetch(`https://dog.ceo/api/breed/${dog.breedSlug}/images/random`)
        .then(r => r.json())
        .then(data => {
          if (data.status === 'success')
            setDogImages(prev => ({ ...prev, [dog.id]: data.message }))
        })
        .catch(() => {})
    })
  }, [])

  useEffect(() => {
    MOCK_DOGS.forEach(dog => {
      api.trackEvent({
        petId: '00000000-0000-0000-0000-00000000000' + dog.id,
        userId: '00000000-0000-0000-0000-000000000002',
        shelterId: '00000000-0000-0000-0000-000000000001',
        eventType: 'pet.viewed',
        occurredAt: new Date().toISOString(),
        metadata: { petName: dog.name },
      }).catch(() => {})
    })
  }, [])

  return (
    <div className="min-h-screen bg-amber-50">
      <div className="bg-amber-700 text-white py-16 px-6 text-center">
        <h1 className="text-4xl font-bold mb-3">Find Your Perfect Companion</h1>
        <p className="text-amber-200 text-lg max-w-xl mx-auto">
          Every dog deserves a loving home. Browse our available dogs and start your adoption journey today.
        </p>
        <button
          onClick={scrollToDogs}
          className="mt-6 bg-white text-amber-700 font-semibold px-6 py-2 rounded-full hover:bg-amber-100 transition"
        >
          Start Adopting
        </button>
      </div>

      <div ref={dogsRef} className="max-w-5xl mx-auto px-6 py-12">
        <h2 className="text-2xl font-bold text-amber-800 mb-6">Dogs Available for Adoption</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {MOCK_DOGS.map(dog => (
            <div key={dog.id} className="bg-white rounded-2xl shadow hover:shadow-md transition overflow-hidden">
              <div className="h-36 overflow-hidden bg-amber-100">
                {dogImages[dog.id]
                  ? <img src={dogImages[dog.id]} alt={dog.name} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center text-6xl select-none">🐕</div>
                }
              </div>
              <div className="p-4">
                <div className="flex items-center justify-between mb-1">
                  <h3 className="text-lg font-bold text-gray-800">{dog.name}</h3>
                  <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${statusStyle[dog.status]}`}>
                    {dog.status}
                  </span>
                </div>
                <p className="text-sm text-gray-500">{dog.breed} · {dog.age}</p>
                <button
                  disabled={dog.status !== 'Available'}
                  onClick={() => setSelectedDog(dog)}
                  className="mt-3 w-full bg-amber-700 hover:bg-amber-600 disabled:bg-gray-200 disabled:text-gray-400 disabled:cursor-not-allowed text-white text-sm font-semibold py-1.5 rounded-lg transition"
                >
                  {dog.status === 'Available' ? 'Adopt Me' : dog.status}
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {selectedDog && (
        <AdoptModal dog={selectedDog} onClose={() => setSelectedDog(null)} />
      )}
    </div>
  )
}
