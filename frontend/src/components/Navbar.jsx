import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";

export default function Navbar() {
  const { isAuthenticated, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  return (
    <nav className="bg-amber-700 text-white px-6 py-4 flex items-center justify-between shadow-md">
      <Link to="/" className="text-xl font-bold tracking-wide">
        Enrique's Dog Adoption Center
      </Link>
      <div className="flex gap-4 items-center text-sm">
        <Link to="/" className="hover:text-amber-200 transition">
          Home
        </Link>
        <Link to="/reviews" className="hover:text-amber-200 transition">
          Reviews
        </Link>
        <Link to="/analytics" className="hover:text-amber-200 transition">
          Analytics
        </Link>
        <Link to="/dog-detect" className="hover:text-amber-200 transition">
          Dog Detect
        </Link>
        {isAuthenticated ? (
          <>
            <Link to="/admin" className="hover:text-amber-200 transition">
              Admin
            </Link>
            <button
              onClick={handleLogout}
              className="bg-amber-900 hover:bg-amber-800 px-3 py-1.5 rounded-lg transition"
            >
              Logout
            </button>
          </>
        ) : (
          <>
            <Link to="/login" className="hover:text-amber-200 transition">
              Login
            </Link>
            <Link
              to="/register"
              className="bg-white text-amber-700 font-semibold px-3 py-1.5 rounded-lg hover:bg-amber-100 transition"
            >
              Register
            </Link>
          </>
        )}
      </div>
    </nav>
  );
}
